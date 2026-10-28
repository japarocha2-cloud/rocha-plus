import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import 'src/cast/cast_readiness.dart';
import 'src/live/channel.dart';
import 'src/screens/adaptive_player_screen.dart';

/// Dedicated debug-only USB entry. No authentication or entitlement requests.
Future<void> main() async {
  if (!kDebugMode || !const bool.fromEnvironment('ROCHA_USB_PHYSICAL_TEST')) {
    throw StateError('USB physical tests require the isolated debug build.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid) throw StateError('Android device required.');
  CastReadiness.initialize(() =>
      GoogleCastContext.instance.setSharedInstanceWithOptions(
        GoogleCastOptionsAndroid(
          appId: GoogleCastDiscoveryCriteria.kDefaultApplicationId,
          stopCastingOnAppTerminated: false,
        ),
      ));
  runApp(const UsbPhysicalTestApp());
}

const usbPhysicalSourceCommit = String.fromEnvironment('ROCHA_SOURCE_COMMIT',
    defaultValue: 'sem identificador');

const usbPhysicalSamples = [
  Channel(name: 'Big Buck Bunny · MP4 de teste',
    url: 'https://storage.googleapis.com/exoplayer-test-media-0/BigBuckBunny_320x180.mp4',
    group: 'Amostras de teste'),
  Channel(name: 'Big Buck Bunny · HLS de teste',
    url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
    group: 'Amostras de teste'),
];

class UsbPhysicalTestApp extends StatelessWidget {
  const UsbPhysicalTestApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    title: 'Rocha+ USB QA',
    home: const _UsbTestHome(),
  );
}

class _UsbTestHome extends StatelessWidget {
  const _UsbTestHome();

  void open(BuildContext context, String engine) {
    final channels = [
      for (final sample in usbPhysicalSamples)
        Channel(name: sample.name, url: sample.url,
            group: sample.group, preferredEngine: engine),
    ];
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AdaptivePlayerScreen(
        channel: channels.first, channels: channels,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rocha+ · Teste USB')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Build isolado para teste físico',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      const Text('Código: $usbPhysicalSourceCommit'),
      const SizedBox(height: 12),
      const Text('Usa somente vídeos de amostra. Não consulta contas, '
          'não altera assinaturas e não modifica o catálogo ou favoritos do aplicativo oficial.'),
      const SizedBox(height: 24),
      FilledButton(
        autofocus: true,
        onPressed: () => open(context, 'exoPlayer'),
        child: const Text('Testar ExoPlayer e Chromecast'),
      ),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: () => open(context, 'libVlc'),
        child: const Text('Testar LibVLC e Chromecast'),
      ),
      const SizedBox(height: 20),
      const Text('No player, use o botão de transmitir para selecionar o Chromecast. '
          'Confirme imagem e áudio na TV durante 60 s e depois 180 s.'),
    ]),
  );
}
