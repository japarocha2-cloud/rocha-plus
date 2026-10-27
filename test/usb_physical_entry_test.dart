import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/usb_physical_main.dart' as usb;

void main() {
  test('dedicated entry rejects launches without explicit debug opt-in', () async {
    await expectLater(usb.main(), throwsStateError);
  });

  test('physical samples use HTTPS without credentials and stay outside the catalogue', () {
    expect(usb.usbPhysicalSamples, hasLength(2));
    for (final channel in usb.usbPhysicalSamples) {
      final uri = Uri.parse(channel.url);
      expect(uri.scheme, 'https');
      expect(uri.userInfo, isEmpty);
      expect(uri.hasQuery, isFalse);
      expect(channel.group, 'Amostras de teste');
    }
  });

  testWidgets('USB screen labels isolated playback tests without account operations', (tester) async {
    await tester.pumpWidget(const usb.UsbPhysicalTestApp());
    await tester.pumpAndSettle();
    expect(find.text('Rocha+ · Teste USB'), findsOneWidget);
    expect(find.text('Testar ExoPlayer e Chromecast'), findsOneWidget);
    expect(find.text('Testar LibVLC e Chromecast'), findsOneWidget);
    expect(find.textContaining('Não consulta contas'), findsOneWidget);
    expect(find.text('Entrar'), findsNothing);
    expect(find.text('Pagar'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
