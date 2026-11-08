import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import 'src/app.dart';
import 'src/cast/cast_readiness.dart';
import 'src/screens/lab_entry_screen.dart';
import 'src/full_ui_lab_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const labOnly = bool.fromEnvironment('ROCHA_LAB_ONLY', defaultValue: false);
  if (Platform.isAndroid && !labOnly) {
    final options = GoogleCastOptionsAndroid(
      appId: GoogleCastDiscoveryCriteria.kDefaultApplicationId,
      stopCastingOnAppTerminated: false,
    );
    CastReadiness.initialize(
      () => GoogleCastContext.instance.setSharedInstanceWithOptions(options),
    );
  }

  const fullUiLab = bool.fromEnvironment('ROCHA_FULL_UI_LAB', defaultValue: false);
  assert(!(labOnly && fullUiLab), 'Choose one LAB entry mode');
  runApp(fullUiLab
      ? const RochaFullUiLabApp()
      : labOnly ? const RochaLabApp() : const RochaPlusApp());
}
