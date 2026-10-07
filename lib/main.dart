import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'src/app.dart';
import 'src/cast/cast_readiness.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    final options = GoogleCastOptionsAndroid(
      appId: GoogleCastDiscoveryCriteria.kDefaultApplicationId,
      stopCastingOnAppTerminated: false,
      physicalVolumeButtonsWillControlDeviceVolume: true,
    );
    CastReadiness.initialize(() =>
        GoogleCastContext.instance.setSharedInstanceWithOptions(options));
  }

  runApp(const RochaPlusApp());
}
