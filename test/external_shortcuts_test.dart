import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rocha_plus/src/ads/external_shortcuts.dart';
import 'package:rocha_plus/src/live/catalog_presentation.dart';

// Every test injects a recording launcher: nothing is opened, no network request.
Widget host(List<Uri> calls, {bool result = true, double width = 412}) => MediaQuery(
      data: MediaQueryData(size: Size(width, 900)),
      child: MaterialApp(home: Scaffold(body: Row(children: [
        for (final s in externalShortcuts)
          Expanded(child: SizedBox(height: 300, child: ExternalShortcutBanner(
            shortcut: s, launcher: (uri) async { calls.add(uri); return result; }))),
      ]))),
    );

void main() {
  test('order and literal URLs are exactly the owner-approved ones', () {
    expect(externalShortcuts.map((s) => s.title), ['AMAMBAI NOTÍCIAS', 'GANHE BR']);
    expect(externalShortcuts[0].url, 'https://www.amambainoticias.com.br/');
    expect(externalShortcuts[1].url, 'http://www.ganhebr47.com/?r=gml4729');
    expect(externalShortcuts[0].insecure, isFalse);
    expect(externalShortcuts[1].insecure, isTrue);
  });

  test('approved art files are vertical 1122x1402 and ratio is preserved', () {
    for (final s in externalShortcuts) {
      final b = File(s.asset).readAsBytesSync();
      final d = ByteData.sublistView(Uint8List.fromList(b.sublist(16, 24)));
      expect([d.getUint32(0), d.getUint32(4)], [1122, 1402], reason: s.asset);
    }
    expect(shortcutArtAspectRatio, closeTo(1122 / 1402, 1e-9));
  });

  test('shortcuts are distinct from the three Home channel highlights', () {
    final titles = externalShortcuts.map((s) => s.title.toLowerCase()).toSet();
    expect(titles.intersection(homeHighlightIdentities.toSet()), isEmpty);
  });

  testWidgets('Amambai opens only on user tap, with the literal https URL and nothing appended', (tester) async {
    final calls = <Uri>[];
    await tester.pumpWidget(host(calls));
    await tester.pumpAndSettle();
    expect(calls, isEmpty, reason: 'never opened while building or rendering');
    await tester.tap(find.byKey(const ValueKey('shortcut-amambai-noticias')));
    await tester.pumpAndSettle();
    expect(calls.map((u) => u.toString()), ['https://www.amambainoticias.com.br/']);
  });

  testWidgets('Ganhe BR (HTTP) shows a security warning; Cancel opens nothing', (tester) async {
    final calls = <Uri>[];
    await tester.pumpWidget(host(calls));
    await tester.tap(find.byKey(const ValueKey('shortcut-ganhe-br')));
    await tester.pumpAndSettle();
    expect(find.text('Site externo sem criptografia'), findsOneWidget);
    expect(find.textContaining('HTTP, sem criptografia'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
  });

  testWidgets('Ganhe BR opens the literal URL only after explicit consent', (tester) async {
    final calls = <Uri>[];
    await tester.pumpWidget(host(calls));
    await tester.tap(find.byKey(const ValueKey('shortcut-ganhe-br')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shortcut-insecure-continue')));
    await tester.pumpAndSettle();
    expect(calls.map((u) => u.toString()), ['http://www.ganhebr47.com/?r=gml4729']);
  });

  testWidgets('missing browser / launch failure shows a message', (tester) async {
    final calls = <Uri>[];
    await tester.pumpWidget(host(calls, result: false));
    await tester.tap(find.byKey(const ValueKey('shortcut-amambai-noticias')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível abrir o navegador'), findsOneWidget);
  });

  testWidgets('remote control: D-pad focus is visible and Select activates', (tester) async {
    final calls = <Uri>[];
    await tester.pumpWidget(host(calls));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(calls.map((u) => u.toString()), ['https://www.amambainoticias.com.br/']);
  });

  for (final width in [320.0, 412.0, 1280.0]) {
    testWidgets('banners render without overflow at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(<Uri>[], width: width));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('shortcut-amambai-noticias')), findsOneWidget);
    });
  }
}
