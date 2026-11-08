import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/full_ui_lab_app.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/theme/rocha_theme.dart';
import 'intro_video_test.dart' show FakeIntroController;

class _Directory extends ChannelRepository {
  @override
  Future<List<Channel>> loadBrazilPublicDirectory({bool forceRefresh = false}) async => const [
    Channel(name: 'CazéTV', url: 'https://example.test/caze', group: 'Esportes'),
  ];
}

double contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance(), b = background.computeLuminance();
  return (a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05));
}

void main() {
  for (final size in [const Size(430, 950), const Size(1920, 1080)]) {
    testWidgets('actual LAB entry preserves dark Android identity and subscription route $size', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(RochaFullUiLabApp(repository: _Directory(),
          introControllerFactory: () => FakeIntroController()));
      await tester.pumpAndSettle();
      expect(find.text('Pular'), findsOneWidget);
      await tester.tap(find.text('Pular'));
      await tester.pumpAndSettle();
      final theme = Theme.of(tester.element(find.byType(HomeScreen)));
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, RochaColors.background);
      expect(contrast(theme.colorScheme.onSurface, theme.colorScheme.surface), greaterThanOrEqualTo(4.5));
      if (size.width < 900) {
        await tester.tap(find.byTooltip('Abrir menu'));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Assinatura'));
      await tester.tap(find.text('Assinatura'));
      await tester.pumpAndSettle();
      expect(find.text('R\$ 7,90 por mês'), findsOneWidget);
      expect(find.text('R\$ 86,90 por ano'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('Teste gratuito de até 7 dias'), 180);
      expect(find.textContaining('Teste gratuito de até 7 dias'), findsOneWidget);
      expect(find.text('Verificar acesso'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
