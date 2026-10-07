import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/screens/live_tv_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
  });
  testWidgets('channel hiding persists and restore brings it back', (tester) async {
    final repo = ChannelRepository(client: MockClient((request) async =>
      http.Response('#EXTM3U\n#EXTINF:-1 group-title="Kids",Canal Criança\n'
          'https://example.com/kids.m3u8\n', 200)));
    await tester.pumpWidget(MaterialApp(home: LiveTvScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Canal Criança'), findsOneWidget);
    await tester.tap(find.byTooltip('Opções de Canal Criança'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocultar canal neste aparelho'));
    await tester.pumpAndSettle();
    expect(find.text('Canal Criança'), findsNothing);
    await tester.tap(find.byTooltip('Opções dos canais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurar canais ocultos'));
    await tester.pumpAndSettle();
    expect(find.text('Canal Criança'), findsOneWidget);
  });
}
