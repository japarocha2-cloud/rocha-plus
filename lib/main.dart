import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'src/app.dart';
import 'src/cast/cast_readiness.dart';
import 'src/screens/lab_entry_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    final options = GoogleCastOptionsAndroid(
      appId: GoogleCastDiscoveryCriteria.kDefaultApplicationId,
      stopCastingOnAppTerminated: false,
    );
    CastReadiness.initialize(() =>
        GoogleCastContext.instance.setSharedInstanceWithOptions(options));
  }

  const labOnly = bool.fromEnvironment('ROCHA_LAB_ONLY', defaultValue: false);
  runApp(labOnly ? const RochaLabApp() : const RochaPlusApp());
}
