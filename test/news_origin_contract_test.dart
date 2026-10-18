import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/news/amambai_news_repository.dart';

void main() {
  final path = Platform.environment['ROCHA_NEWS_HTML_FIXTURE'];
  test('live publisher HTML still yields a dated editorial preview and photo', () async {
    final source = await File(path!).readAsString();
    final headline = AmambaiNewsRepository.parseHomepage(source, DateTime.now());
    expect(headline, isNotNull);
    expect(headline!.image, isNotNull);
    expect(headline.title, isNotEmpty);
    expect(headline.publishedAt.isAfter(DateTime.now()), isFalse);
  }, skip: path == null);
}
