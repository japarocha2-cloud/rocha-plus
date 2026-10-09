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

  test('all 45 failed device entries stay excluded after feed URL changes', () {
    final repo = ChannelRepository();
    const failedDeviceEntries = [
      'Adjarasport 1',
      'Alfa Sport (1080p) [Not 24/7]',
      'Awapa Sports TV (1080p) [Not 24/7]',
      'Bahrain Sports 1 (720p) [Not 24/7]',
      'Barca TV',
      'Belarus-5 (1080p) [Not 24/7]',
      'Belarus-5 Internet (1080p) [Not 24/7]',
      'Bellator MMA',
      'Billiard TV (1080p) [Geo-blocked]',
      'Brondby TV',
      'Canal+ Sport 360',
      'CBC Sport [Geo-blocked]',
      'CBS Sports Golazo Network (720p)',
      'CBS Sports HQ (720p)',
      'CCTV-5+',
      'Cricket Gold (1080p)',
      'DAZN Combat (684p)',
      'DAZN Darts x Pluto TV',
      'DAZN Heldinnen x Pluto TV',
      'DD Sports (720p)',
      'Deportes por Movistar Plus+',
      'Digi Sport 1',
      'Digi Sport 2 HD (1080i)',
      'Dong Nai TV 2 (720p)',
      'Esport3 (1080p) [Geo-blocked]',
      'Esport3 Originals (1080p) [Not 24/7]',
      'F1 Channel (1080p) [Geo-blocked]',
      'FCK Lovinderne',
      'FIFA+ (720p)',
      'Fight Network (1080p)',
      'FightBox',
      'Fubo Sports Network (1080p)',
      'FUEL TV US (1080p) [Geo-blocked]',
      'Futbol (1080p)',
      'GEM Fit',
      'GEM Sport',
      'Golazo Network (720p)',
      'Golf Channel',
      'Hard Knocks (1080p)',
      'HTV Sports',
      'IRIB 3',
      'Record RS (720p) [Geo-blocked]',
      'SBT Cuiaba',
      'SBT Nova Mutum',
      'SBT Rondonopolis',
    ];
    for (final name in failedDeviceEntries) {
      final channel = Channel(name: name, url: 'https://example.com/replaced-feed.m3u8',
          group: 'Esportes');
      expect(repo.isBlocked(channel), isTrue, reason: name);
      expect(repo.sportsOnly([channel]), isEmpty, reason: name);
    }
    ChannelRepository.resetSessionHealthForTests();
    expect(ChannelRepository().isBlocked(const Channel(
      name: 'SBT Cuiaba', url: 'https://example.com/another.m3u8',
      group: 'TV aberta')), isTrue);
  });

  test('device entries without failure retain eligibility, including similar names', () {
    final repo = ChannelRepository();
    const retainedDeviceEntries = [
      'Strongman Champions League (720p)',
      'FIFA+ Portuguese (720p)',
      'ge Fast (1080p)',
      'N Sports (1080p)',
      'Red Bull TV BR (1080p)',
      'A Spor SD (1080p)',
      'ACC Digital Network (1080p)',
      'ACI Sport TV SD (1080p)',
      'ADO TV (720p)',
      'Africa 24 Sport (1080p)',
      'Al Iraqia Sport (720p)',
      'AS3 Sport TV (1080p)',
      'Astrahan.Ru Sport (720p)',
      'ATG Live (720p)',
      'Bahrain Sports 2 (720p) [Not 24/7]',
      'beIN SPORTS XTRA (1080p)',
      'BEK Sports West (720p)',
      'Canal Showsport (720p)',
      'CDN Deportes (720p) [Not 24/7]',
      'Colimdo TV (720p)',
      'CRTV (Chile) (720p)',
      'DD Sports SD (1080p)',
      'DraftKings Network (1080p)',
      'El-Heddaf TV (1080p)',
      'Equidia (1080p)',
      'ESPN8: The Ocho (1080p)',
      'Fast&FunBox (Netherlands)',
      'FIFA+ French (720p)',
      'FIFA+ German (720p)',
      'FIFA+ Hispanic America (720p)',
      'FIFA+ Italy (720p)',
      'FIFA+ Spain (720p)',
      'FIFA+ United States (720p)',
      'FIFA+ Women (720p)',
      'FightBox HD',
      'FITE 24/7 (1080p)',
      'FloHockey (1080p)',
      'FloRacing (1080p)',
      'FTF Sports (720p)',
      'FTV (Bolivia) (720p)',
      'FUEL TV (1080p)',
      'FUEL TV AU (1080p)',
      'Game+ (720p)',
      'Glory Kickboxing Poland (720p)',
      'Horse TV (720p)',
      'HTSpor TV (1080p)',
      'Inter TV (Italy) (1080p)',
      'InTrouble (1080p)',
      'ITV Deportes (720p)',
      'Jordan Sport (1080p) [Geo-blocked]',
      'Rede Globo (1080p)',
      'RedeTV! Parana',
      'SBT Interior (720p)',
      'SBT Nacional (1080p)',
      'TV Pantanal MS (360p) [Not 24/7]',
    ];
    for (final name in retainedDeviceEntries) {
      expect(repo.isBlocked(Channel(name: name,
        url: 'https://example.com/retained.m3u8', group: 'Esportes')),
        isFalse, reason: name);
    }
  });
}
