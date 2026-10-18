import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/app.dart';

void main() {
  testWidgets('lab navigation and resize leave no obstructed tooltip overlay', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const RochaPlusApp());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(milliseconds: 500));
    final tooltip = find.byTooltip('Abrir canais para transmitir');
    final tooltipState = tester.state<TooltipState>(tooltip);
    tooltipState.ensureTooltipVisible();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // A route can cover its owner while its tooltip is still mounted. In
    // Flutter 3.47.6 resizing that offstage overlay asserts debugNeedsLayout.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Outra tela'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    tester.view.physicalSize = const Size(915, 412);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }, skip: !const bool.fromEnvironment('ROCHA_LAB_TEST'));
}
