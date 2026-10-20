import 'package:flutter/material.dart';

import '../live/channel.dart';
import '../live/lab_catalog.dart';
import 'player_lab_screen.dart';

/// Test build entrypoint: no Firebase login, purchases, or catalogue mutation.
/// This entry is compiled only by ROCHA_LAB_ONLY and never affects production.
class RochaLabApp extends StatelessWidget {
  const RochaLabApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Rocha+ Laboratório',
    theme: ThemeData.dark(useMaterial3: true),
    home: const _LabCatalogueLoader(),
  );
}

class _LabCatalogueLoader extends StatefulWidget {
  const _LabCatalogueLoader();
  @override
  State<_LabCatalogueLoader> createState() => _LabCatalogueLoaderState();
}

class _LabCatalogueLoaderState extends State<_LabCatalogueLoader> {
  Future<List<Channel>>? _loading;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final loading = loadLabCatalog().catchError((
      Object error,
      StackTrace stack,
    ) {
      debugPrint('LAB catalogue startup failed: $error');
      Error.throwWithStackTrace(error, stack);
    });
    setState(() {
      _loading = loading;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Channel>>(
    future: _loading,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Scaffold(
          appBar: AppBar(title: const Text('Rocha+ LAB • experimental')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (snapshot.hasError)
                  const Text('Não foi possível carregar o catálogo.'),
                if (!snapshot.hasError) const CircularProgressIndicator(),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _reload,
                  child: const Text('Atualizar canais'),
                ),
              ],
            ),
          ),
        );
      }
      return PlayerLabScreen(channels: snapshot.data!);
    },
  );
}
