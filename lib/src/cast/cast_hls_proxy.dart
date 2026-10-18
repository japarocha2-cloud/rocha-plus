import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Same-Wi-Fi fallback for HLS that the receiver cannot fetch directly.
/// Original encoded media bytes are forwarded without transcoding.
class CastHlsProxy {
  CastHlsProxy._()
      : _client = http.Client(),
        _resolve = ((host) => InternetAddress.lookup(host, type: InternetAddressType.IPv4)),
        _testAddress = null;

  @visibleForTesting
  CastHlsProxy.testing({
    required http.Client client,
    required Future<List<InternetAddress>> Function(String) resolve,
  }) : _client = client, _resolve = resolve,
       _testAddress = InternetAddress.loopbackIPv4;

  static final instance = CastHlsProxy._();
  final http.Client _client;
  final Future<List<InternetAddress>> Function(String) _resolve;
  final InternetAddress? _testAddress;
  final _random = Random.secure();
  final _targets = <String, Uri>{};
  final _tokens = <String, String>{};
  HttpServer? _server;
  Timer? _expiry;

  static bool privateIpv4(InternetAddress address) {
    if (address.type != InternetAddressType.IPv4) return false;
    final b = address.rawAddress;
    return b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
        (b[0] == 192 && b[1] == 168);
  }

  static bool publicAddress(InternetAddress address) {
    if (address.type != InternetAddressType.IPv4) return false;
    final b = address.rawAddress;
    return !privateIpv4(address) && b[0] != 0 && b[0] != 127 &&
        !(b[0] == 169 && b[1] == 254) && b[0] < 224 &&
        !(b[0] == 100 && b[1] >= 64 && b[1] <= 127) &&
        !(b[0] == 198 && (b[1] == 18 || b[1] == 19));
  }

  Future<void> _validate(Uri uri) async {
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw StateError('Relay exige uma fonte HTTPS sem credenciais.');
    }
    final addresses = await _resolve(uri.host).timeout(const Duration(seconds: 5));
    if (addresses.isEmpty || !addresses.every(publicAddress)) {
      throw StateError('Destino não público recusado pelo relay.');
    }
  }

  Future<Uri> relay(Uri source) async {
    await _validate(source);
    if (_server == null) {
      InternetAddress? address = _testAddress;
      if (address == null) {
        final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
        interfaces.sort((a, b) =>
            (b.name.toLowerCase().contains('wlan') ? 1 : 0)
            .compareTo(a.name.toLowerCase().contains('wlan') ? 1 : 0));
        for (final interface in interfaces) {
          final candidates = interface.addresses.where(privateIpv4);
          if (candidates.isNotEmpty) { address = candidates.first; break; }
        }
      }
      if (address == null) throw StateError('Rede Wi-Fi IPv4 local não disponível.');
      _server = await HttpServer.bind(address, 0);
      _server!.listen(_handle);
    }
    _renewExpiry();
    return _link(source);
  }

  void _renewExpiry() {
    _expiry?.cancel();
    _expiry = Timer(const Duration(hours: 2), () { close(); });
  }

  Future<void> close() async {
    _expiry?.cancel();
    _expiry = null;
    final server = _server;
    _server = null;
    _targets.clear();
    _tokens.clear();
    await server?.close(force: true);
  }

  Uri _link(Uri target) {
    if (target.scheme != 'https' || target.host.isEmpty || target.userInfo.isNotEmpty) {
      throw StateError('Referência HLS insegura recusada.');
    }
    final key = target.toString();
    var token = _tokens[key];
    if (token == null) {
      if (_targets.length >= 4096) {
        final oldest = _targets.keys.first;
        _tokens.remove(_targets.remove(oldest).toString());
      }
      token = base64UrlEncode(List.generate(24, (_) => _random.nextInt(256)));
      _tokens[key] = token;
      _targets[token] = target;
    }
    final server = _server!;
    return Uri(scheme: 'http', host: server.address.address,
        port: server.port, path: '/hls', queryParameters: {'id': token});
  }

  String _rewrite(String body, Uri base) => body.split('\n').map((line) {
    if (line.trim().isEmpty) return line;
    if (line.trimLeft().startsWith('#')) {
      return line.replaceAllMapped(RegExp(r'URI="([^"]+)"'), (match) =>
          'URI="${_link(base.resolve(match.group(1)!))}"');
    }
    return _link(base.resolve(line.trim())).toString();
  }).join('\n');

  Future<({http.StreamedResponse response, Uri uri})> _fetch(
      Uri target, String method, String? range) async {
    for (var redirect = 0; redirect <= 4; redirect++) {
      await _validate(target);
      final upstream = http.Request(method, target)..followRedirects = false;
      if (range != null) upstream.headers['Range'] = range;
      final response = await _client.send(upstream).timeout(const Duration(seconds: 8));
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers['location'];
        await response.stream.drain<void>().timeout(const Duration(seconds: 8));
        if (location == null) throw StateError('Redirecionamento sem destino.');
        target = target.resolve(location);
        continue;
      }
      return (response: response, uri: target);
    }
    throw StateError('Redirecionamentos excessivos no sinal.');
  }

  Future<void> _handle(HttpRequest request) async {
    final out = request.response;
    final peer = request.connectionInfo?.remoteAddress;
    if (peer == null || (!privateIpv4(peer) &&
        !(_testAddress != null && peer.isLoopback))) {
      out.statusCode = HttpStatus.forbidden;
      await out.close(); return;
    }
    final token = request.uri.queryParameters['id'];
    final target = _targets[token];
    if (request.uri.path != '/hls' || target == null) {
      out.statusCode = HttpStatus.notFound;
      await out.close(); return;
    }
    out.headers.set('Access-Control-Allow-Origin', '*');
    out.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
    out.headers.set('Access-Control-Allow-Headers', 'Range, Content-Type');
    out.headers.set('Access-Control-Expose-Headers', 'Content-Length, Content-Range, Accept-Ranges');
    if (request.method == 'OPTIONS') {
      out.statusCode = HttpStatus.noContent; await out.close(); return;
    }
    if (request.method != 'GET' && request.method != 'HEAD') {
      out.statusCode = HttpStatus.methodNotAllowed; await out.close(); return;
    }
    _renewExpiry();
    try {
      final result = await _fetch(target, request.method,
          request.headers.value(HttpHeaders.rangeHeader));
      final response = result.response;
      out.statusCode = response.statusCode;
      final type = response.headers['content-type'] ?? '';
      final playlist = result.uri.path.toLowerCase().endsWith('.m3u8') ||
          result.uri.path.toLowerCase().endsWith('.m3u') || type.toLowerCase().contains('mpegurl');
      if (playlist && request.method == 'GET' && response.statusCode == 200) {
        final bytes = <int>[];
        await for (final chunk in response.stream.timeout(const Duration(seconds: 8))) {
          bytes.addAll(chunk);
          if (bytes.length > 1024 * 1024) throw StateError('Playlist muito grande.');
        }
        out.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
        out.write(_rewrite(utf8.decode(bytes), result.uri));
      } else {
        for (final name in ['content-type', 'content-range', 'accept-ranges']) {
          final value = response.headers[name];
          if (value != null) out.headers.set(name, value);
        }
        if (request.method == 'GET') {
          await out.addStream(response.stream.timeout(const Duration(seconds: 8)));
        } else {
          await response.stream.drain<void>().timeout(const Duration(seconds: 8));
        }
      }
    } catch (_) {
      try { out.statusCode = HttpStatus.badGateway; } catch (_) { /* headers sent */ }
    }
    try { await out.close(); } catch (_) { /* receiver disconnected */ }
  }
}
