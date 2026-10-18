import 'dart:io';
import 'package:flutter/foundation.dart';

/// Local, credential-free diagnostics for the separately packaged lab APK.
/// This does not intercept errors or change red-screen rendering in production.
void installLabDiagnostics() {
  if (!const bool.fromEnvironment('ROCHA_LAB_TEST')) return;
  final directory = Platform.isAndroid
      ? '/data/data/com.rochaplus.labpositivos/cache'
      : Directory.systemTemp.path;
  final file = File('$directory/rocha_lab_errors.log');
  void record(String error) {
    try {
      file.writeAsStringSync('${DateTime.now().toIso8601String()}\n$error\n',
        mode: FileMode.append, flush: true);
    } catch (_) { /* A diagnostic write must never prevent app startup. */ }
  }
  try { file.writeAsStringSync('Rocha+ local lab diagnostics\n'); } catch (_) {}
  final previousFlutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    record(details.toString());
    previousFlutterHandler?.call(details);
  };
  final previousPlatformHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    record('$error\n$stack');
    return previousPlatformHandler?.call(error, stack) ?? false;
  };
}
