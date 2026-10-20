import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/catalog_presentation.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/screens/live_tv_screen.dart';

class EmptyApprovedRepository extends ChannelRepository {
  @override
  Future<List<Channel>> loadBrazilPublicDirectory({
    bool forceRefresh = false,
  }) async => [];
}

class MovieRepository extends ChannelRepository {
  @override
  Future<List<Channel>> loadBrazilPublicDirectory({
    bool forceRefresh = false,
  }) async => const [
    Channel(
      name: 'Canal Comédia',
      url: 'https://example.test/comedy',
      group: 'Filmes',
      genres: ['Comédia'],
    ),
    Channel(
      name: 'Canal Ação',
      url: 'https://example.test/action',
      group: 'Filmes',
      genres: ['Ação'],
    ),
    Channel(
      name: 'Canal Sem Gênero',
      url: 'https://example.test/unknown',
      group: 'Filmes',
    ),
  ];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
  });
  test('familiar brands appear before alphabetical channels', () {
    const channels = [
      Channel(name: 'Alpha', url: 'a', group: 'TV aberta'),
      Channel(name: 'Band', url: 'b', group: 'TV aberta'),
      Channel(name: 'TV Morena', url: 'g', group: 'TV aberta'),
    ];
    expect(popularChannelsFirst(channels).map((c) => c.name), [
      'TV Morena',
      'Band',
      'Alpha',
    ]);
  });
  testWidgets(
    'new film and religious cards open real empty approved categories',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = EmptyApprovedRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(repository: repository, laboratoryFeatures: true),
        ),
      );
      await tester.pumpAndSettle();
      for (final category in ['Filmes', 'Religiosos']) {
        final card = find.byKey(ValueKey('category-$category'));
        await tester.scrollUntilVisible(
          card,
          250,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('home-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.byType(LiveTvScreen), findsOneWidget);
        expect(find.text('Nenhum canal encontrado.'), findsOneWidget);
        expect(
          tester.widget<LiveTvScreen>(find.byType(LiveTvScreen)).initialGroup,
          category,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    },
  );
  testWidgets('movies filter by known genre and retain unknown as explicit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LiveTvScreen(
          initialGroup: 'Filmes',
          repository: MovieRepository(),
          laboratoryFeatures: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comédia').last);
    await tester.pumpAndSettle();
    expect(find.text('Canal Comédia'), findsOneWidget);
    expect(find.text('Canal Ação'), findsNothing);
    expect(find.text('Canal Sem Gênero'), findsNothing);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sem gênero informado').last);
    await tester.pumpAndSettle();
    expect(find.text('Canal Sem Gênero'), findsOneWidget);
    expect(find.text('Canal Comédia'), findsNothing);
  });
}
