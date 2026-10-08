import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/channel.dart';

void main() {
  test('competition bonuses preserve tiers and unrelated football names stay below soccer', () {
    final repo = ChannelRepository();
    const male = Channel(name: 'Futebol', url: 'https://example.com/a', group: 'Esportes');
    const female = Channel(name: 'Futebol feminino Brasileirão Champions Libertadores',
        url: 'https://example.com/b', group: 'Esportes');
    const nfl = Channel(name: 'American Football NFL', url: 'https://example.com/c', group: 'Esportes');
    expect(repo.sportsOnly([nfl, female, male]), [male, female, nfl]);
  });

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

  test('physical-test blocklist survives remote URL changes', () {
    final repository = ChannelRepository();
    const blockedA = Channel(
      name: '1001 Noites',
      url: 'https://example.com/old-feed.m3u8',
      group: 'General',
    );
    const blockedB = Channel(
      name: '  1001 NOITES  ',
      url: 'https://example.com/new-feed.m3u8',
      group: 'Geral',
    );
    const allowed = Channel(
      name: 'N Sports',
      url: 'https://example.com/nsports.m3u8',
      group: 'Esportes',
    );

    expect(repository.isPermanentlyBlockedForTests(blockedA), isTrue);
    expect(repository.isPermanentlyBlockedForTests(blockedB), isTrue);
    expect(repository.isPermanentlyBlockedForTests(allowed), isFalse);
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
  test('physical block applies to sports and survives resolution suffix changes', () {
    final repo = ChannelRepository();
    const blocked = Channel(name: 'Band Sports (720p)',
        url: 'https://example.com/new.m3u8', group: 'Esportes');
    expect(repo.isBlocked(blocked), isTrue);
    expect(repo.sportsOnly([blocked]), isEmpty);
  });
}

