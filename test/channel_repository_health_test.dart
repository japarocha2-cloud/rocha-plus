import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/channel.dart';

void main() {
  setUp(ChannelRepository.resetSessionHealthForTests);

  test('player failure quarantines a stream for the current session', () {
    final repository = ChannelRepository();
    const url = 'https://example.com/live.m3u8';

    expect(repository.isQuarantined(url), isFalse);
    repository.reportPlaybackFailure(url);
    expect(repository.isQuarantined(url), isTrue);
  });

  test('successful playback clears a previous quarantine', () {
    final repository = ChannelRepository();
    const url = 'https://example.com/live.m3u8';

    repository.reportPlaybackFailure(url);
    repository.reportPlaybackSuccess(url);
    expect(repository.isQuarantined(url), isFalse);
  });

  test('sports catalog excludes non-sports and quarantined streams', () {
    final repository = ChannelRepository();
    const sport = Channel(name: 'Futebol Brasil', url: 'https://example.com/sport.m3u8', group: 'Esportes');
    const news = Channel(name: 'Jornal', url: 'https://example.com/news.m3u8', group: 'News');

    expect(repository.sportsOnly([sport, news]), [sport]);
    repository.reportPlaybackFailure(sport.url);
    expect(repository.sportsOnly([sport, news]), isEmpty);
  });

  test('male football ranks before female football and other sports', () {
    final repository = ChannelRepository();
    const male = Channel(name: 'Brasileirão Futebol', url: 'https://example.com/a.m3u8', group: 'Esportes');
    const female = Channel(name: 'Futebol Feminino', url: 'https://example.com/b.m3u8', group: 'Esportes');
    const tennis = Channel(name: 'Tênis', url: 'https://example.com/c.m3u8', group: 'Esportes');

    expect(repository.sportsPriorityForTests(male), greaterThan(repository.sportsPriorityForTests(female)));
    expect(repository.sportsPriorityForTests(female), greaterThan(repository.sportsPriorityForTests(tennis)));
    expect(repository.sportsOnly([tennis, female, male]), [male, female, tennis]);
  });
}

