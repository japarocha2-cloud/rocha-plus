import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import '../theme/rocha_theme.dart';

class CastDevicePicker extends StatefulWidget {
  final ValueChanged<GoogleCastDevice> onSelected;
  final Stream<List<GoogleCastDevice>>? devicesStream;
  final List<GoogleCastDevice>? initialDevices;
  final Future<void> Function()? startDiscovery;
  final Future<void> Function()? stopDiscovery;
  const CastDevicePicker({
    super.key, required this.onSelected, this.devicesStream,
    this.initialDevices, this.startDiscovery, this.stopDiscovery,
  });

  @override
  State<CastDevicePicker> createState() => _CastDevicePickerState();
}

class _CastDevicePickerState extends State<CastDevicePicker> {
  StreamSubscription<List<GoogleCastDevice>>? _subscription;
  Timer? _timer;
  List<GoogleCastDevice> _devices = [];
  bool _searching = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _devices = widget.initialDevices ??
        GoogleCastDiscoveryManager.instance.devices;
    // Subscribe before starting discovery so the first native event is retained.
    _subscription = (widget.devicesStream ??
        GoogleCastDiscoveryManager.instance.devicesStream).listen((devices) {
      if (mounted) setState(() { _devices = devices; _error = false; });
    }, onError: (Object error) {
      if (mounted) setState(() { _error = true; _searching = false; });
    });
    _discover();
  }

  Future<void> _discover() async {
    _timer?.cancel();
    setState(() { _searching = true; _error = false; });
    _timer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _searching = false);
    });
    try {
      await (widget.startDiscovery ??
          GoogleCastDiscoveryManager.instance.startDiscovery)();
    } catch (_) {
      if (mounted) setState(() { _error = true; _searching = false; });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    unawaited(_stop());
    super.dispose();
  }

  Future<void> _stop() async {
    try {
      await (widget.stopDiscovery ??
          GoogleCastDiscoveryManager.instance.stopDiscovery)();
    } catch (_) {
      // Closing the picker must remain possible if the native service is gone.
    }
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .7,
    ),
    child: _devices.isNotEmpty
        ? ListView.builder(
            shrinkWrap: true,
            itemCount: _devices.length,
            itemBuilder: (_, index) => ListTile(
              autofocus: index == 0,
              leading: const Icon(Icons.cast, color: RochaColors.gold),
              title: Text(_devices[index].friendlyName),
              onTap: () => widget.onSelected(_devices[index]),
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_searching)
                const CircularProgressIndicator(color: RochaColors.ruby),
              const SizedBox(height: 16),
              Text(_error
                  ? 'Não foi possível procurar TVs.'
                  : _searching
                      ? 'Procurando TVs e Chromecasts na mesma rede Wi-Fi...'
                      : 'Nenhuma TV encontrada. Confira se os aparelhos estão na mesma rede Wi-Fi.'),
              if (!_searching)
                TextButton(onPressed: _discover,
                    child: const Text('Procurar novamente')),
            ]),
          ),
  );
}
