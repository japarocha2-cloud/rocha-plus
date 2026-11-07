import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/screens/lab_entry_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bridge = MethodChannel('com.rochaplus.app/lab');
  testWidgets(
    'LAB opens fixture catalogue without returning a Future from setState',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(bridge, (call) async {
        if (call.method == 'configuration') {
          return {'fixture': true, 'auto': false, 'limit': 2, 'offset': 0};
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(bridge, null));
      await tester.pumpWidget(const RochaLabApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('LAB controlled A/V fixture'), findsOneWidget);
      expect(find.text('LAB deliberate HTTP 404'), findsOneWidget);
      expect(find.text('Iniciar pendentes'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
