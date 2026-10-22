import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/favorites_repository.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/screens/live_tv_screen.dart';

const _a = Channel(name: 'Favorito da conta A', url: 'https://example.test/a');
const _b = Channel(name: 'Favorito da conta B', url: 'https://example.test/b');

class _EmptyChannels extends ChannelRepository {
  @override
  Future<List<Channel>> loadBrazilPublicDirectory({bool forceRefresh = false})
      async => [];
}

class _DelayedChannels extends ChannelRepository {
  final requests = <Completer<List<Channel>>>[];
  @override
  Future<List<Channel>> loadBrazilPublicDirectory({bool forceRefresh = false}) {
    final request = Completer<List<Channel>>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'favorite_channel_urls': ['https://example.test/legacy'],
    });
    ChannelRepository.resetSessionHealthForTests();
  });

  test('A, B and guest stay separate across writes and reopening', () async {
    final a = FavoritesRepository(accountUid: 'A');
    final b = FavoritesRepository(accountUid: 'B');
    final guest = FavoritesRepository();
    expect(await a.load(), isEmpty);
    expect(await b.load(), isEmpty);
    expect(await guest.load(), isEmpty);
    await a.save({_a.url});
    await b.save({_b.url});
    await guest.save({'https://example.test/guest'});
    expect(await FavoritesRepository(accountUid: 'A').load(), {_a.url});
    expect(await FavoritesRepository(accountUid: 'B').load(), {_b.url});
    expect(await FavoritesRepository().load(), {'https://example.test/guest'});
    await b.save({});
    expect(await a.load(), {_a.url});
    expect(await b.load(), isEmpty);
    expect((await SharedPreferences.getInstance())
        .getStringList('favorite_channel_urls'), ['https://example.test/legacy']);
  });

  test('pending write stays with the identity captured before account switch', () async {
    var uid = 'A';
    final original = FavoritesRepository(accountUid: uid);
    final pending = original.save({_a.url});
    uid = 'B';
    final next = FavoritesRepository(accountUid: uid);
    await next.save({_b.url});
    await pending;
    expect(await FavoritesRepository(accountUid: 'A').load(), {_a.url});
    expect(await next.load(), {_b.url});
    expect(await FavoritesRepository().load(), isEmpty);
  });

  testWidgets('late A load cannot replace B favorites after account switch',
      (tester) async {
    await FavoritesRepository(accountUid: 'A').save({_a.url});
    await FavoritesRepository(accountUid: 'B').save({_b.url});
    final channels = _DelayedChannels();
    Widget screen(String uid) => MaterialApp(home: LiveTvScreen(
      initialGroup: 'Favoritos', repository: channels, accountUid: uid,
    ));
    await tester.pumpWidget(screen('A'));
    await tester.pumpWidget(screen('B'));
    expect(channels.requests, hasLength(2));
    channels.requests[1].complete([_a, _b]);
    await tester.pumpAndSettle();
    expect(find.text(_b.name), findsOneWidget);
    expect(find.text(_a.name), findsNothing);
    channels.requests[0].complete([_a, _b]);
    await tester.pumpAndSettle();
    expect(find.text(_b.name), findsOneWidget);
    expect(find.text(_a.name), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home passes its UID to search and category routes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: HomeScreen(
      repository: _EmptyChannels(), accountUid: 'A',
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-search')));
    await tester.pumpAndSettle();
    expect(tester.widget<LiveTvScreen>(find.byType(LiveTvScreen)).accountUid, 'A');
    await tester.pageBack();
    await tester.pumpAndSettle();
    final category = find.byKey(const ValueKey('category-TV ao Vivo'));
    await tester.ensureVisible(category);
    await tester.tap(category);
    await tester.pumpAndSettle();
    expect(tester.widget<LiveTvScreen>(find.byType(LiveTvScreen)).accountUid, 'A');
  });
}
