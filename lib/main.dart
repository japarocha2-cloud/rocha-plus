import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    const configuredCastAppId = String.fromEnvironment('ROCHA_CAST_APP_ID');
    final castAppId = configuredCastAppId.isEmpty
        ? GoogleCastDiscoveryCriteria.kDefaultApplicationId
        : configuredCastAppId;
    final options = GoogleCastOptionsAndroid(
      appId: castAppId,
      stopCastingOnAppTerminated: false,
    );
    GoogleCastContext.instance.setSharedInstanceWithOptions(options);
  }

  runApp(const RochaPlusApp());
}
