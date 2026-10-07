import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:rocha_plus/src/cast/cast_device_picker.dart';

class TestDevice extends Fake implements GoogleCastDevice {
  @override
  String get friendlyName => 'TV da sala';
}

void main() {
  testWidgets('keeps cached receivers and stops discovery on close', (tester) async {
    var stopped = false;
    final device = TestDevice();
    GoogleCastDevice? selected;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CastDevicePicker(
      initialDevices: [device],
      devicesStream: const Stream.empty(),
      startDiscovery: () async {},
      stopDiscovery: () async { stopped = true; },
      onSelected: (value) => selected = value,
    ))));
    expect(find.text('TV da sala'), findsOneWidget);
    await tester.tap(find.text('TV da sala'));
    expect(selected, same(device));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(stopped, isTrue);
  });

  testWidgets('captures an event emitted during discovery startup', (tester) async {
    final stream = StreamController<List<GoogleCastDevice>>.broadcast(sync: true);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CastDevicePicker(
      initialDevices: const [],
      devicesStream: stream.stream,
      startDiscovery: () async { stream.add([TestDevice()]); },
      stopDiscovery: () async {},
      onSelected: (_) {},
    ))));
    await tester.pump();
    expect(find.text('TV da sala'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await stream.close();
  });

  testWidgets('empty scan ends with retry and native errors stay visible', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CastDevicePicker(
      initialDevices: const [],
      devicesStream: const Stream.empty(),
      startDiscovery: () async {
        attempts++;
        if (attempts > 1) throw StateError('native unavailable');
      },
      stopDiscovery: () async {},
      onSelected: (_) {},
    ))));
    await tester.pump(const Duration(seconds: 13));
    expect(find.textContaining('Nenhuma TV encontrada'), findsOneWidget);
    await tester.tap(find.text('Procurar novamente'));
    await tester.pump();
    expect(find.text('Não foi possível procurar TVs.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
