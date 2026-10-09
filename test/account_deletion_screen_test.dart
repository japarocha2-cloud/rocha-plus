import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';

class EmptyDirectory extends ChannelRepository {
  @override
  Future<List<Channel>> loadBrazilPublicDirectory() async => [];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('cancel never invokes account deletion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var requests = 0;
    await tester.pumpWidget(MaterialApp(home: HomeScreen(
      repository: EmptyDirectory(),
      onDeleteAccount: () async { requests++; return null; },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir conta'));
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(find.text('Excluir conta do Rocha+?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('confirmed deletion shows backend failure without leaving home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var requests = 0;
    await tester.pumpWidget(MaterialApp(home: HomeScreen(
      repository: EmptyDirectory(),
      onDeleteAccount: () async { requests++; return 'Entre novamente na mesma conta'; },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Excluir conta'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.text('Entre novamente na mesma conta'), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
