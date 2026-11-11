import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/screens/cast_control_screen.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932),
      const Size(960, 540), const Size(1920, 1080)]) {
    testWidgets('Cast tabs and controls fit $size in phone/TV layout', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(MaterialApp(home: CastControlView(
        channel: const Channel(name: 'Canal Teste',
          url: 'https://example.com/live', group: 'TV aberta'),
        deviceName: 'TV da sala', status: 'Transmitindo agora',
        connected: true, playing: true, onBack: () {},
        onToggle: () {}, onDisconnect: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cast-scroll')), findsOneWidget);
      expect(find.text('Transmitindo para'), findsOneWidget);
      expect(find.byType(AspectRatio), findsOneWidget);
      expect(find.byTooltip('Pausar na TV'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Detalhes'));
      await tester.pumpAndSettle();
      expect(find.text('Canal Teste'), findsOneWidget);
      expect(find.byTooltip('Pausar na TV'), findsNothing);
      expect(find.byType(AspectRatio), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Controles'));
      await tester.pumpAndSettle();
      expect(find.text('Canal Teste'), findsNothing);
      expect(find.byTooltip('Pausar na TV'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
