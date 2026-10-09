import 'package:flutter/material.dart';
import '../live/favorites_repository.dart';
import '../live/channel.dart';
class FavoritesSyncNotice extends StatelessWidget {
  final FavoritesRepository repository;
  final List<Channel> catalog;
  const FavoritesSyncNotice({super.key, required this.repository, required this.catalog});
  @override
  Widget build(BuildContext context) {
    if (!repository.cloud) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.cloud_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(repository.status, key: const ValueKey('favorites-sync-status'),
            style: const TextStyle(color: Colors.white70))),
          if (repository.error != null) TextButton(onPressed: repository.retry,
            child: const Text('Tentar novamente')),
        ]),
        const Text('Entre com a mesma conta para encontrar seus favoritos em outro aparelho.',
          style: TextStyle(color: Colors.white54, fontSize: 12)),
        if (repository.legacyUrls.isNotEmpty) TextButton(
          child: const Text('Importar favoritos deste aparelho'),
          onPressed: () async {
            final confirmed = await showDialog<bool>(context: context, builder: (_) =>
              AlertDialog(title: const Text('Adicionar à sua conta?'),
                content: const Text('Os favoritos antigos deste aparelho serão adicionados à conta atual. Importe somente se forem seus.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Importar')),
                ]));
            if (confirmed != true) return;
            try { await repository.importLegacy(catalog); }
            catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('A importação não foi concluída. Confira a conexão e tente novamente.')));
              }
            }
          }),
      ]));
  }
}
