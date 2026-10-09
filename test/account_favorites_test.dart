import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/favorite_entry.dart';
import 'package:rocha_plus/src/live/favorites_repository.dart';

const a = Channel(name: 'Canal A', url: 'https://example.com/a.m3u8');
const b = Channel(name: 'Canal B', url: 'https://example.com/b.m3u8');

class MemoryServer {
  final entries = <String, FavoriteEntry>{};
  final changes = StreamController<FavoritesSnapshot>.broadcast(sync: true);
  bool hold = false;
  bool fail = false;
  final writes = <Completer<void>>[];
  FavoritesSnapshot get snapshot => FavoritesSnapshot(entries.values.toList());
  void publish() => changes.add(snapshot);
}
class MemoryStore implements FavoritesStore {
  final MemoryServer server;
  MemoryStore(this.server);
  @override
  Stream<FavoritesSnapshot> watch() async* {
    yield server.snapshot;
    yield* server.changes.stream;
  }
  @override
  Future<void> put(FavoriteEntry entry) async {
    if (server.fail) throw StateError('permission-denied');
    if (server.hold) {
      final gate = Completer<void>(); server.writes.add(gate); await gate.future;
    }
    server.entries[entry.id] = entry; server.publish();
  }
  @override
  Future<void> remove(String id) async {
    if (server.fail) throw StateError('permission-denied');
    if (server.hold) {
      final gate = Completer<void>(); server.writes.add(gate); await gate.future;
    }
    server.entries.remove(id); server.publish();
  }
}
Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('reinstall with cleared local storage restores account favorites and order', () async {
    final server = MemoryServer();
    final first = FavoritesRepository(store: MemoryStore(server));
    await first.load();
    await first.toggle(a); await flush();
    await first.toggle(b); await flush();
    first.dispose();
    SharedPreferences.setMockInitialValues({});
    final restored = FavoritesRepository(store: MemoryStore(server));
    await restored.load();
    expect(restored.savedChannels([a, b]).map((c) => c.name), ['Canal A', 'Canal B']);
    expect(restored.confirmed, isTrue);
    restored.dispose(); await server.changes.close();
  });
  test('two devices add separate channels without overwriting and propagate removals', () async {
    final server = MemoryServer();
    final one = FavoritesRepository(store: MemoryStore(server));
    final two = FavoritesRepository(store: MemoryStore(server));
    await one.load(); await two.load(); await flush();
    await one.toggle(a); await two.toggle(b); await flush();
    expect(one.values, {FavoritesRepository.idFor(a), FavoritesRepository.idFor(b)});
    expect(two.values, one.values);
    await two.toggle(a); await flush();
    expect(one.savedChannels([a,b]).map((c)=>c.name), ['Canal B']);
    one.dispose(); two.dispose(); await server.changes.close();
  });
  test('account isolation and expired session prevent mutations', () async {
    final alice = MemoryServer(), bob = MemoryServer();
    var active = true;
    final one = FavoritesRepository(store: MemoryStore(alice), isCurrentAccount: ()=>active);
    final two = FavoritesRepository(store: MemoryStore(bob));
    await one.load(); await two.load();
    await one.toggle(a); await flush();
    expect(two.values, isEmpty);
    active = false;
    await expectLater(one.toggle(b), throwsStateError);
    expect(alice.entries.length, 1);
    one.dispose(); two.dispose(); await alice.changes.close(); await bob.changes.close();
  });
  test('URL updates preserve channel selection and missing catalog retains saved metadata', () async {
    final server = MemoryServer();
    final repo = FavoritesRepository(store: MemoryStore(server));
    await repo.load(); await repo.toggle(a); await flush();
    const updated = Channel(name: 'Canal A (720p)', url: 'https://example.com/new.m3u8');
    expect(repo.contains(repo.values, updated), isTrue);
    expect(repo.savedChannels([updated]).single.url, updated.url);
    expect(repo.savedChannels([]).single.name, a.name);
    repo.dispose(); await server.changes.close();
  });
  test('offline write stays pending until acknowledgement, then restores elsewhere', () async {
    final server = MemoryServer()..hold = true;
    final repo = FavoritesRepository(store: MemoryStore(server));
    await repo.load(); await repo.toggle(a); await flush();
    expect(repo.syncing, isTrue); expect(repo.confirmed, isFalse);
    expect(repo.contains(repo.values, a), isTrue);
    server.writes.single.complete(); await flush();
    expect(repo.confirmed, isTrue);
    final other = FavoritesRepository(store: MemoryStore(server));
    await other.load(); expect(other.values, repo.values);
    repo.dispose(); other.dispose(); await server.changes.close();
  });
  test('denied save rolls back and exposes failure without false confirmation', () async {
    final server = MemoryServer()..fail = true;
    final repo = FavoritesRepository(store: MemoryStore(server));
    await repo.load(); await repo.toggle(a); await flush();
    expect(repo.values, isEmpty); expect(repo.error, isNotNull);
    expect(repo.confirmed, isFalse);
    server.fail = false; await repo.retry(); await repo.toggle(a); await flush();
    expect(repo.confirmed, isTrue);
    repo.dispose(); await server.changes.close();
  });
  test('rapid add then remove keeps latest local intent while writes are pending', () async {
    final server = MemoryServer()..hold = true;
    final repo = FavoritesRepository(store: MemoryStore(server));
    await repo.load(); await repo.toggle(a); await repo.toggle(a); await flush();
    expect(repo.values, isEmpty); expect(repo.syncing, isTrue);
    server.writes[0].complete(); await flush();
    expect(repo.values, isEmpty);
    server.writes[1].complete(); await flush();
    expect(repo.values, isEmpty); expect(repo.confirmed, isTrue);
    repo.dispose(); await server.changes.close();
  });
  test('cached snapshot is not labelled as server-confirmed', () async {
    final server = MemoryServer();
    final repo = FavoritesRepository(store: MemoryStore(server));
    await repo.load(); await flush();
    server.changes.add(const FavoritesSnapshot([], fromCache: true));
    expect(repo.confirmed, isFalse); expect(repo.status, contains('Aguardando conexão'));
    server.publish(); expect(repo.confirmed, isTrue);
    repo.dispose(); await server.changes.close();
  });
  test('legacy device list requires explicit import and preserves existing cloud favorites', () async {
    SharedPreferences.setMockInitialValues({'favorite_channel_urls': [a.url]});
    final server = MemoryServer();
    final repo = FavoritesRepository(store: MemoryStore(server));
    await repo.load();
    expect(repo.values, isEmpty); expect(repo.legacyUrls, {a.url});
    await repo.toggle(b); await flush();
    await repo.importLegacy([a,b]); await flush();
    expect(repo.values.length, 2);
    repo.dispose(); await server.changes.close();
  });
  test('disposing cancels listeners and ignores late acknowledgements', () async {
    final server = MemoryServer()..hold = true;
    final repo = FavoritesRepository(store: MemoryStore(server));
    await repo.load(); await repo.toggle(a); await flush();
    repo.dispose(); server.writes.single.complete(); await flush();
    await expectLater(repo.toggle(b), throwsStateError);
    await server.changes.close();
  });
}
