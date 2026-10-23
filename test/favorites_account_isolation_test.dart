import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/favorites_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({
    'favorite_channel_urls': ['https://legacy.example/channel.m3u8'],
  }));
  test('account switching keeps each favorite list separate', () async {
    final first = FavoritesRepository(accountId: 'account-a');
    final second = FavoritesRepository(accountId: 'account-b');
    const channel = 'https://example.com/channel.m3u8';
    expect(await first.load(), isEmpty);
    await first.save({channel});
    expect(await second.load(), isEmpty);
    await second.save({'https://example.com/other.m3u8'});
    expect(await FavoritesRepository(accountId: 'account-a').load(), {channel});
    await first.save({});
    expect(await second.load(), {'https://example.com/other.m3u8'});
  });
  test('signed out sessions cannot access or save account favorites', () async {
    final repository = FavoritesRepository(accountId: null);
    expect(await repository.load(), {'https://legacy.example/channel.m3u8'});
    await repository.save({'https://example.com/a'});
    expect(await repository.load(), {'https://example.com/a'});
  });
}
