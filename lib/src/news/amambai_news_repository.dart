import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NewsHeadline {
  final String title;
  final String summary;
  final Uri article;
  final Uri? image;
  final DateTime publishedAt;
  const NewsHeadline({required this.title, required this.summary,
    required this.article, required this.publishedAt, this.image});

  Map<String, Object?> toJson() => {'title': title, 'summary': summary,
    'article': article.toString(), 'image': image?.toString(),
    'publishedAt': publishedAt.toIso8601String()};
}

/// A single external news preview. Never loads article bodies or modifies channels.
class AmambaiNewsRepository {
  static final homepage = Uri.parse('https://www.amambainoticias.com.br/');
  static final shared = AmambaiNewsRepository();
  static const refreshInterval = Duration(minutes: 15);
  static const _cacheKey = 'amambai_news_preview.v1';
  final http.Client _client;
  final DateTime Function() _now;
  Future<NewsHeadline?>? _pending;
  NewsHeadline? _cached;
  DateTime? _lastAttempt;
  AmambaiNewsRepository({http.Client? client, DateTime Function()? now})
      : _client = client ?? http.Client(), _now = now ?? DateTime.now;

  static Uri? trustedUri(String? value, {bool image = false}) {
    final uri = Uri.tryParse(value ?? '');
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty ||
        uri.port != 443 || !{'amambainoticias.com.br', 'www.amambainoticias.com.br'}.contains(uri.host)) return null;
    if (image) {
      if (!uri.path.startsWith('/wp-content/uploads/') ||
          !RegExp(r'\.(jpe?g|png|webp)$', caseSensitive: false).hasMatch(uri.path)) return null;
    } else if (!RegExp(r'^/20\d\d/\d\d/\d\d/[^/]+/$').hasMatch(uri.path)) {
      return null;
    }
    return Uri(scheme: 'https', host: uri.host, path: uri.path);
  }

  static String _clean(String value, int maxWords) => value
      .replaceAll(RegExp(r'\s+'), ' ').trim().split(' ').take(maxWords).join(' ');

  /// Select dated editorial previews, excluding the fixed commercial hero tiles.
  static NewsHeadline? parseHomepage(String body, DateTime now) {
    final document = html.parse(body);
    final candidates = <NewsHeadline>[];
    for (final module in document.querySelectorAll('.td_module_wrap')) {
      final link = module.querySelector('.entry-title a');
      final excerpt = module.querySelector('.td-excerpt');
      final published = DateTime.tryParse(module.querySelector('time[datetime]')?.attributes['datetime'] ?? '');
      final uri = trustedUri(link?.attributes['href']);
      if (link == null || excerpt == null || uri == null || published == null ||
          published.isAfter(now.add(const Duration(minutes: 5)))) continue;
      final title = _clean(link.text, 18);
      if (title.isEmpty) continue;
      // Title + short excerpt stays within 25 words per live preview.
      final words = title.split(' ').length;
      final summary = _clean(excerpt.text, 25 - words);
      final image = trustedUri(module.querySelector('[data-img-url]')?.attributes['data-img-url'] ??
        module.querySelector('img')?.attributes['src'], image: true);
      candidates.add(NewsHeadline(title: title, summary: summary,
        article: uri, image: image, publishedAt: published));
    }
    candidates.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return candidates.isEmpty ? null : candidates.first;
  }

  Future<NewsHeadline?> load() {
    if (_pending != null) return _pending!;
    if (_lastAttempt != null && _now().difference(_lastAttempt!) < refreshInterval) {
      return Future.value(_freshCache());
    }
    return _pending = _load().whenComplete(() => _pending = null);
  }

  NewsHeadline? _freshCache() => _cached != null &&
      _now().difference(_cached!.publishedAt) <= const Duration(days: 7)
      ? _cached : null;

  void _trace(String value) {
    if (const bool.fromEnvironment('ROCHA_LAB_TEST')) debugPrint('[RochaNews] $value');
  }

  Future<NewsHeadline?> _load() async {
    _lastAttempt = _now();
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (_cached == null && raw != null) {
        final value = jsonDecode(raw) as Map<String, dynamic>;
        final article = trustedUri(value['article'] as String?);
        final date = DateTime.tryParse(value['publishedAt'] as String? ?? '');
        if (article != null && date != null && !date.isAfter(_now())) {
          final title = _clean(value['title'] as String, 18);
          _cached = NewsHeadline(title: title,
            summary: _clean(value['summary'] as String? ?? '', 25 - title.split(' ').length),
            article: article, image: trustedUri(value['image'] as String?, image: true), publishedAt: date);
        }
      }
    } catch (_) { /* Invalid or unavailable preview cache cannot block Home. */ }
    try {
      final request = http.Request('GET', homepage)..followRedirects = false;
      final response = await _client.send(request).timeout(const Duration(seconds: 8));
      _trace('http=${response.statusCode}');
      if (response.statusCode != 200) return _freshCache();
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(const Duration(seconds: 8))) {
        bytes.addAll(chunk);
        if (bytes.length > 2 * 1024 * 1024) throw const FormatException('News preview too large');
      }
      final result = parseHomepage(utf8.decode(bytes), _now());
      _trace('bytes=${bytes.length} parsed=${result != null} clock=${_now().toIso8601String()}');
      if (result != null) {
        _cached = result;
        try { await prefs?.setString(_cacheKey, jsonEncode(result.toJson())); } catch (_) {}
      }
    } catch (error) {
      _trace('load-failure=${error.runtimeType}: $error');
      // Keep the last valid preview; no error dialog or route changes.
    }
    return _freshCache();
  }
}
