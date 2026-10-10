import 'channel.dart';

class FavoriteEntry {
  final String id;
  final Channel channel;
  final int addedAt;
  const FavoriteEntry({required this.id, required this.channel, required this.addedAt});
}
class FavoritesSnapshot {
  final List<FavoriteEntry> entries;
  final bool pending;
  final bool fromCache;
  const FavoritesSnapshot(this.entries, {this.pending = false, this.fromCache = false});
}
abstract class FavoritesStore {
  Stream<FavoritesSnapshot> watch();
  Future<void> put(FavoriteEntry entry);
  Future<void> remove(String id);
}
