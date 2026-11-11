import 'package:cloud_firestore/cloud_firestore.dart';
import 'channel.dart';
import 'favorite_entry.dart';

class FirestoreFavoritesStore implements FavoritesStore {
  final CollectionReference<Map<String, dynamic>> collection;
  FirestoreFavoritesStore(String uid, {FirebaseFirestore? firestore})
    : collection = (firestore ?? FirebaseFirestore.instance)
        .collection('users').doc(uid).collection('favorites');
  @override
  Stream<FavoritesSnapshot> watch() => collection
    .snapshots(includeMetadataChanges: true).map((snapshot) {
      final entries = snapshot.docs.map((doc) {
        final data = doc.data();
        return FavoriteEntry(id: doc.id,
          channel: Channel(name: data['name'] as String, url: data['url'] as String,
            group: data['group'] as String, logo: data['logo'] as String?),
          addedAt: (data['addedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0);
      }).toList()..sort((a, b) {
        final order = a.addedAt.compareTo(b.addedAt);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
      return FavoritesSnapshot(entries, pending: snapshot.metadata.hasPendingWrites,
        fromCache: snapshot.metadata.isFromCache);
    });
  @override
  Future<void> put(FavoriteEntry entry) => collection.doc(entry.id).set({
    'name': entry.channel.name, 'url': entry.channel.url, 'group': entry.channel.group,
    'logo': entry.channel.logo, 'addedAt': FieldValue.serverTimestamp(),
  });
  @override
  Future<void> remove(String id) => collection.doc(id).delete();
}
