// Diagnostic entry point used only inside CI. It exposes no player or auth bypass
// and is never published as a downloadable candidate.
import 'package:flutter/material.dart';
import 'src/live/channel_repository.dart';
import 'src/live/favorites_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Catalog probe')))));
  try {
    final repository = ChannelRepository();
    final favoritesRepository = FavoritesRepository(accountId: 'catalog-probe');
    final results = await Future.wait([
      repository.loadBrazilPublicDirectory(), favoritesRepository.load(),
    ]);
    final channels = await repository.loadBrazilPublicDirectory();
    if (results[0] is! List || results[1] is! Set) {
      throw StateError('Concurrent catalogue/favorite loading failed');
    }
    if (channels.isEmpty || !channels.any((c) => c.group == 'Notícias')) {
      throw StateError('Packaged catalogue is empty');
    }
    await favoritesRepository.save({channels.first.url});
    if (!(await favoritesRepository.load()).contains(channels.first.url)) {
      throw StateError('Favorite persistence failed');
    }
    await repository.blockChannel(channels.first);
    if ((await ChannelRepository().loadBrazilPublicDirectory())
        .any((channel) => channel.url == channels.first.url)) {
      throw StateError('Explicit channel block was lost');
    }
    await repository.restoreUserBlockedChannels();
    final restored = await repository.loadBrazilPublicDirectory();
    if (restored.length != channels.length) {
      final before = channels.map((c) => c.url).toSet();
      final after = restored.map((c) => c.url).toSet();
      throw StateError('Restoring user-hidden channels failed '
        'before=${channels.length} after=${restored.length} '
        'missing=${before.difference(after)} extra=${after.difference(before)}');
    }
    await favoritesRepository.save({});
    // ignore: avoid_print
    print('ROCHA_CATALOG_PROBE_OK channels=${channels.length} preferences=read-write-verified');
  } catch (error, stack) {
    // ignore: avoid_print
    print('ROCHA_CATALOG_PROBE_FAILURE $error\n$stack');
  }
}
