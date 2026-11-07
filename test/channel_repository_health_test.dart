import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/playback_failure.dart';

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

  test('transient player failure records diagnosis without quarantining a stream', () {
    final repository = ChannelRepository();
    const url = 'https://example.com/live.m3u8';

    expect(repository.isQuarantined(url), isFalse);
    repository.reportPlaybackFailure(url, failure: PlaybackFailure.timeout);
    expect(repository.isQuarantined(url), isFalse);
    expect(repository.lastPlaybackFailure(url), PlaybackFailure.timeout);
  });

  test('successful playback clears the previous failure diagnosis', () {
    final repository = ChannelRepository();
    const url = 'https://example.com/live.m3u8';

    repository.reportPlaybackFailure(url);
    repository.reportPlaybackSuccess(url);
    expect(repository.isQuarantined(url), isFalse);
    expect(repository.lastPlaybackFailure(url), isNull);
  });

  test('sports catalog excludes non-sports but preserves channels after transient failure', () {
    final repository = ChannelRepository();
    const sport = Channel(name: 'Futebol Brasil', url: 'https://example.com/sport.m3u8', group: 'Esportes');
    const news = Channel(name: 'Jornal', url: 'https://example.com/news.m3u8', group: 'News');

    expect(repository.sportsOnly([sport, news]), [sport]);
    repository.reportPlaybackFailure(sport.url);
    expect(repository.sportsOnly([sport, news]), [sport]);
  });

  test('historical names alone cannot block current or alternative feeds', () {
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

    expect(repository.isPermanentlyBlockedForTests(blockedA), isFalse);
    expect(repository.isPermanentlyBlockedForTests(blockedB), isFalse);
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
  test('historical sports name does not suppress a different resolution', () {
    final repo = ChannelRepository();
    const blocked = Channel(name: 'Band Sports (720p)',
        url: 'https://example.com/new.m3u8', group: 'Esportes');
    expect(repo.isBlocked(blocked), isFalse);
    expect(repo.sportsOnly([blocked]), [blocked]);
  });
  test('all eleven historical names remain visible without an explicit user block', () {
    final repository = ChannelRepository();
    for (final name in [
      '1001 Noites', '30A Golf Kingdom (720p)', 'Pluto TV Esportes',
      'Canal do Inter (720p) [not 24/7]', 'Band Sports (1080p)',
      'Times Brasil (720p)', 'TV Thathi (720p) [not 24/7]',
      'TV Sul de Minas (720p)', 'TV Meio (720p)',
      'TV Difusora Leste (1080p)', 'TV Encontro das Aguas',
    ]) {
      final channel = Channel(name: name, url: 'https://example.com/live',
          group: 'Esportes');
      expect(repository.isBlocked(channel), isFalse, reason: name);
      expect(repository.sportsOnly([channel]), [channel], reason: name);
    }
  });
}
