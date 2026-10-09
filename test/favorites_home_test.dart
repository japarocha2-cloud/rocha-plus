import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/account_favorites.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/favorite_entry.dart';
import 'package:rocha_plus/src/live/favorites_repository.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/screens/live_tv_screen.dart';
import 'package:rocha_plus/src/widgets/rocha_channel_card.dart';

class Catalog extends ChannelRepository {
  final List<Channel> channels;
  Catalog(this.channels);
  @override
  Future<List<Channel>> loadBrazilPublicDirectory({bool forceRefresh = false}) async => channels;
}
class SavedStore implements FavoritesStore {
  final List<FavoriteEntry> entries;
  SavedStore(this.entries);
  @override
  Stream<FavoritesSnapshot> watch() => Stream.value(FavoritesSnapshot(entries));
  @override
  Future<void> put(FavoriteEntry entry) async {}
  @override
  Future<void> remove(String id) async {}
}
class TrackedRepository extends FavoritesRepository {
  bool wasDisposed = false;
  @override
  void dispose() { wasDisposed = true; super.dispose(); }
}
void main() {
  setUp(() { SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests(); });
  testWidgets('changing account replaces and disposes previous favorites session', (tester) async {
    final created = <TrackedRepository>[];
    Widget account(String uid) => MaterialApp(home: AccountFavorites(uid: uid,
      repositoryFactory: (_) {
        final repo = TrackedRepository(); created.add(repo); return repo;
      }, builder: (_) => Text(uid)));
    await tester.pumpWidget(account('alice'));
    await tester.pumpWidget(account('bob'));
    expect(created.length, 2);
    expect(created.first.wasDisposed, isTrue);
    expect(created.last.wasDisposed, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(created.last.wasDisposed, isTrue);
  });
  testWidgets('Home highlights all saved channels above the carousel and shares account repository', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final channels = List.generate(13, (i) =>
      Channel(name: 'Favorite $i', url: 'https://example.com/$i.m3u8', group: 'Geral'));
    final repo = FavoritesRepository(store: SavedStore(List.generate(channels.length,
      (i)=> FavoriteEntry(id: FavoritesRepository.idFor(channels[i]),
        channel: channels[i], addedAt: i))));
    await tester.pumpWidget(MaterialApp(home: HomeScreen(
      repository: Catalog(channels), favoritesRepository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Meus favoritos'), findsOneWidget);
    expect(find.text('Favoritos salvos na sua conta'), findsOneWidget);
    final cards = find.byType(RochaChannelCard);
    expect(cards, findsWidgets);
    final row = find.ancestor(of: cards.first, matching: find.byType(ListView)).first;
    final delegate = (tester.widget<ListView>(row).childrenDelegate as SliverChildBuilderDelegate);
    expect(delegate.childCount, 25); // 13 cards plus 12 separators.
    expect(tester.getTopLeft(find.text('Meus favoritos')).dy,
      lessThan(tester.getTopLeft(find.text('Explore o Rocha+')).dy));
    await tester.tap(find.text('Ver todos').first); await tester.pumpAndSettle();
    final screen = tester.widget<LiveTvScreen>(find.byType(LiveTvScreen));
    expect(identical(screen.favoritesRepository, repo), isTrue);
    expect(find.text('13 canais'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); repo.dispose();
  });
  testWidgets('favorites destination retains stored channel when directory temporarily omits it', (tester) async {
    const channel = Channel(name: 'Favorite absent', url: 'https://example.com/a.m3u8');
    final repo = FavoritesRepository(store: SavedStore([
      FavoriteEntry(id: FavoritesRepository.idFor(channel), channel: channel, addedAt: 1)]));
    await tester.pumpWidget(MaterialApp(home: LiveTvScreen(
      initialGroup: 'Favoritos', repository: Catalog([]), favoritesRepository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Favorite absent'), findsOneWidget);
    expect(find.text('1 canais'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); repo.dispose();
  });
}
