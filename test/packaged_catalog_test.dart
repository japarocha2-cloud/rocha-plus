import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/screens/live_tv_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('the actual packaged catalogue loads without a network fallback', () async {
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
    final channels = await ChannelRepository().loadBrazilPublicDirectory();
    expect(channels, isNotEmpty);
    expect(channels.where((c) => c.group == 'Notícias'), hasLength(5));
    expect(channels.where((c) => c.name.startsWith('SBC TV')), hasLength(1));
    expect(channels, hasLength(194));
    expect(channels.where((c) => c.group == 'Infantil'), hasLength(5));
    expect(channels.where((c) => c.name == 'SBC Kids'), hasLength(1));
    expect(channels.where((c) => c.name == 'Kuriakos Kids'), hasLength(1));
    expect(channels.where((c) => c.name == '3ABN Kids'), hasLength(1));
    expect(channels.where((c) => c.group == 'TV aberta').length, greaterThan(50));
  });
  testWidgets('News renders the real packaged channels after account preference loading', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
    final repository = ChannelRepository();
    await tester.runAsync(() => repository.loadBrazilPublicDirectory());
    await tester.pumpWidget(MaterialApp(home: LiveTvScreen(
      initialGroup: 'Notícias', accountId: 'catalog-test', repository: repository)));
    await tester.pumpAndSettle();
    expect(find.text('5 canais'), findsOneWidget);
    expect(find.byKey(const ValueKey('channel-grid')), findsOneWidget);
    expect(find.text('Não foi possível carregar os canais.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
