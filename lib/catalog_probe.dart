// Diagnostic entry point used only inside CI. It exposes no player or auth bypass
// and is never published as a downloadable candidate.
import 'package:flutter/material.dart';
import 'src/live/channel_repository.dart';
import 'src/live/favorites_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Catalog probe')))));
  try {
    final channels = await ChannelRepository().loadBrazilPublicDirectory();
    final favorites = await FavoritesRepository(accountId: 'catalog-probe').load();
    if (channels.isEmpty || !channels.any((c) => c.group == 'Notícias')) {
      throw StateError('Packaged catalogue is empty');
    }
    // ignore: avoid_print
    print('ROCHA_CATALOG_PROBE_OK channels=${channels.length} favorites=${favorites.length}');
  } catch (error, stack) {
    // ignore: avoid_print
    print('ROCHA_CATALOG_PROBE_FAILURE $error\n$stack');
  }
}
