import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Local HLS relay used only for public/authorized streams when the Cast
/// receiver cannot fetch the origin directly (for example because of CORS or
/// origin/header restrictions). The Chromecast fetches the stream from the
/// phone on the same Wi-Fi network.
class CastHlsProxy {
  CastHlsProxy._();
  static final CastHlsProxy instance = CastHlsProxy._();

  HttpServer? _server;
  HttpClient? _client;
  String? _host;
  final Random _random = Random.secure();
  final Map<String, Uri> _targets = <String, Uri>{};

  Future<Uri> relay(Uri source) async {
    await _ensureStarted();
    return _proxyUri(source);
  }

  Future<void> _ensureStarted() async {
    if (_server != null && _host != null) return;

    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final addresses = interfaces
        .expand((interface) => interface.addresses)
        .where((address) => !address.isLoopback)
        .toList();
    if (addresses.isEmpty) {
      throw StateError('Nenhum IPv4 local disponível para o Cast.');
    }

    _host = addresses.first.address;
    _client = HttpClient();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0, shared: true);
    _server!.listen(_handleRequest);
  }

  Uri _proxyUri(Uri target) {
    final server = _server;
    final host = _host;
    if (server == null || host == null) {
      throw StateError('Relay do Cast não iniciado.');
    }

    final bytes = List<int>.generate(18, (_) => _random.nextInt(256));
    final token = base64UrlEncode(bytes).replaceAll('=', '');
    _targets[token] = target;

    if (_targets.length > 2048) {
      _targets.remove(_targets.keys.first);
    }

    return Uri(
      scheme: 'http',
      host: host,
      port: server.port,
      path: '/relay',
      queryParameters: {'t': token},
    );
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.method != 'GET' && request.method != 'HEAD') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }

    final token = request.uri.queryParameters['t'];
    final target = token == null ? null : _targets[token];
    if (target == null || (target.scheme != 'http' && target.scheme != 'https')) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    try {
      final upstream = await _client!.openUrl(request.method, target);
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null) upstream.headers.set(HttpHeaders.rangeHeader, range);
      upstream.headers.set(
        HttpHeaders.userAgentHeader,
        request.headers.value(HttpHeaders.userAgentHeader) ?? 'Mozilla/5.0 RochaPlus Cast',
      );
      upstream.headers.set(HttpHeaders.acceptHeader, '*/*');

      final response = await upstream.close();
      request.response.statusCode = response.statusCode;
      final contentType = response.headers.contentType?.mimeType.toLowerCase() ?? '';
      final isPlaylist = target.path.toLowerCase().endsWith('.m3u8') ||
          target.path.toLowerCase().endsWith('.m3u') ||
          contentType.contains('mpegurl');

      if (isPlaylist && request.method != 'HEAD') {
        request.response.headers.contentType =
            ContentType('application', 'vnd.apple.mpegurl', charset: 'utf-8');
        final body = await utf8.decoder.bind(response).join();
        request.response.write(_rewritePlaylist(body, target));
      } else {
        final upstreamType = response.headers.contentType;
        if (upstreamType != null) {
          request.response.headers.contentType = upstreamType;
        }
        final acceptRanges = response.headers.value(HttpHeaders.acceptRangesHeader);
        if (acceptRanges != null) {
          request.response.headers.set(HttpHeaders.acceptRangesHeader, acceptRanges);
        }
        final contentRange = response.headers.value(HttpHeaders.contentRangeHeader);
        if (contentRange != null) {
          request.response.headers.set(HttpHeaders.contentRangeHeader, contentRange);
        }
        if (request.method != 'HEAD') {
          await response.pipe(request.response);
          return;
        }
      }
    } catch (_) {
      request.response.statusCode = HttpStatus.badGateway;
    }
    await request.response.close();
  }

  String _rewritePlaylist(String playlist, Uri base) {
    final uriAttribute = RegExp(r'URI="([^"]+)"');
    return playlist.split('\n').map((line) {
      if (line.trim().isEmpty) return line;
      if (line.startsWith('#')) {
        return line.replaceAllMapped(uriAttribute, (match) {
          final resolved = base.resolve(match.group(1)!);
          return 'URI="${_proxyUri(resolved)}"';
        });
      }
      return _proxyUri(base.resolve(line.trim())).toString();
    }).join('\n');
  }
}
