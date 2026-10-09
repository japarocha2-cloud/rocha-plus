import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/billing/billing_controller.dart';
import 'package:rocha_plus/src/billing/subscription_gate.dart';
import 'package:rocha_plus/src/billing/subscription_screen.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/favorite_entry.dart';
import 'package:rocha_plus/src/live/favorites_repository.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/screens/news_screen.dart';
import 'package:rocha_plus/src/screens/live_tv_screen.dart';

class TestBilling extends BillingController {
  TestBilling({super.beta = false}) : super('alice');
  @override
  Future<void> initialize() async {}
  @override
  Future<void> refresh() async {}
}
class TestCatalog extends ChannelRepository {
  @override
  Future<List<Channel>> loadBrazilPublicDirectory({bool forceRefresh = false}) async => [];
}
class TestStore implements FavoritesStore {
  final FavoriteEntry entry;
  TestStore(this.entry);
  @override
  Stream<FavoritesSnapshot> watch() => Stream.value(FavoritesSnapshot([entry]));
  @override
  Future<void> put(FavoriteEntry entry) async {}
  @override
  Future<void> remove(String id) async {}
}
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
  });
  testWidgets('expiry blocks channel routes and renewal recovers the same account favorites',
      (tester) async {
    const channel = Channel(name: 'Saved Record', url: 'https://example.com/record.m3u8');
    final favorites = FavoritesRepository(store: TestStore(FavoriteEntry(
      id: FavoritesRepository.idFor(channel), channel: channel, addedAt: 1)));
    final billing = TestBilling();
    void grant() => billing.apply({'active': true, 'state': 'SUBSCRIPTION_STATE_ACTIVE',
      'expiresAt': DateTime.now().millisecondsSinceEpoch + 60000, 'autoRenewing': true});
    grant();
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: SubscriptionGate(uid: 'alice',
      favoritesRepository: favorites, billingController: billing,
      channelRepository: TestCatalog(), onSignOut: () async {})));
    await tester.pumpAndSettle();
    expect(find.text('Meus favoritos'), findsOneWidget);
    expect(identical(tester.widget<HomeScreen>(find.byType(HomeScreen)).favoritesRepository,
      favorites), isTrue);
    // A route on the channel navigator must be discarded when access expires.
    final context = tester.element(find.byType(HomeScreen));
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Open channel route'))));
    await tester.pumpAndSettle();
    expect(find.text('Open channel route'), findsOneWidget);
    billing.apply({'active': false, 'state': 'SUBSCRIPTION_STATE_EXPIRED', 'expiresAt': 1});
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Open channel route'), findsNothing);
    expect(find.byType(SubscriptionScreen), findsOneWidget);
    expect(favorites.savedChannels([]).single.name, 'Saved Record');
    grant();
    await tester.pumpAndSettle();
    expect(find.text('Meus favoritos'), findsOneWidget);
    expect(identical(tester.widget<HomeScreen>(find.byType(HomeScreen)).favoritesRepository,
      favorites), isTrue);
    await tester.pumpWidget(const SizedBox());
    favorites.dispose(); billing.dispose();
  });
  testWidgets('beta shares account favorites and keeps purchases disabled', (tester) async {
    final favorites = FavoritesRepository();
    final billing = TestBilling(beta: true);
    await tester.pumpWidget(MaterialApp(home: SubscriptionGate(uid: 'alice',
      favoritesRepository: favorites, billingController: billing,
      channelRepository: TestCatalog(), onSignOut: () async {})));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(billing.allowed, isTrue);
    expect(billing.offers, isEmpty);
    final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
    expect(home.onSubscription, isNotNull);
    expect(identical(home.favoritesRepository, favorites), isTrue);
    final homeContext = tester.element(find.byType(HomeScreen));
    home.onSubscription!(homeContext);
    await tester.pumpAndSettle();
    expect(find.byType(SubscriptionScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SubscriptionScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    bool fullscreen = true;
    final context = tester.element(find.byType(HomeScreen));
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
      StatefulBuilder(builder: (context, setState) => PopScope(
        canPop: !fullscreen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => fullscreen = false);
        },
        child: Scaffold(body: Text(fullscreen ? 'Fullscreen route' : 'Normal route'))))));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Normal route'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Normal route'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    favorites.dispose(); billing.dispose();
  });
  testWidgets('news uses the same account favorites store as Home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final favorites = FavoritesRepository();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(
      repository: TestCatalog(), favoritesRepository: favorites)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notícias').first);
    await tester.pumpAndSettle();
    expect(find.byType(NewsScreen), findsOneWidget);
    expect(identical(tester.widget<LiveTvScreen>(find.byType(LiveTvScreen))
      .favoritesRepository, favorites), isTrue);
    await tester.pumpWidget(const SizedBox());
    favorites.dispose();
  });
}
