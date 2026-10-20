import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import 'src/app.dart';
import 'src/cast/cast_readiness.dart';
import 'src/screens/lab_entry_screen.dart';

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

  runApp(labOnly ? const RochaLabApp() : const RochaPlusApp());
}
