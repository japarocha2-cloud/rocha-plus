import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/app.dart';
import 'package:rocha_plus/src/field_test_mode.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/screens/login_screen.dart';

void main() {
  testWidgets('TV test APK opens Home immediately without sign-in', (tester) async {
    // Run this test with --dart-define=ROCHA_TV_FIELD_TEST=true.
    expect(rochaTvFieldTest, isTrue);
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const RochaPlusApp());
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('TV ao Vivo'), findsWidgets);
    expect(find.byKey(const ValueKey('home-preview-notice')), findsNothing);
    expect(tester.takeException(), isNull);
  }, skip: !rochaTvFieldTest);
}
