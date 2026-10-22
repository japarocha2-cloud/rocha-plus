import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Debug LAB bridge only; no external storage or production writes.
class LabRuntime {
  static const _bridge = MethodChannel('com.rochaplus.app/lab');
  final Directory directory;
  LabRuntime._(this.directory);

  static Future<Map<String, dynamic>> configuration() async {
    try {
      return Map<String, dynamic>.from(
        await _bridge.invokeMapMethod<String, dynamic>('configuration') ?? {},
      );
    } on MissingPluginException {
      return {};
    }
  }

  static Future<LabRuntime?> open() async {
    try {
      final path = await _bridge.invokeMethod<String>('directory');
      if (path == null) return null;
      final directory = Directory(path);
      await directory.create(recursive: true);
      return LabRuntime._(directory);
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> write(String name, Object data) async =>
      writeText(name, const JsonEncoder.withIndent('  ').convert(data));

  Future<void> writeText(String name, String data) async {
    final target = File('${directory.path}/$name');
    final pending = File('${target.path}.tmp');
    await pending.writeAsString(data, flush: true);
    await pending.rename(target.path);
  }

  Future<Map<String, dynamic>> read(String name) async {
    final file = File('${directory.path}/$name');
    if (!await file.exists()) return {};
    return Map<String, dynamic>.from(
      jsonDecode(await file.readAsString()) as Map,
    );
  }
}
