import 'dart:async';

import 'package:flutter/foundation.dart';

import '../cast/cast_connection_observer.dart';
import 'channel.dart';

/// One selection shared by the local player and the Cast controller.
/// A receiver failure never commits a new channel name or content ID.
class ChannelPlaybackSession extends ChangeNotifier {
  ChannelPlaybackSession({
    required Channel initial,
    required Iterable<Channel> channels,
    bool Function(Channel)? allowed,
  }) : current = initial,
       _allowed = allowed ?? ((_) => true) {
    final unique = <String, Channel>{};
    for (final channel in [initial, ...channels]) {
      if (_allowed(channel)) unique.putIfAbsent(channel.url, () => channel);
    }
    playlist = List.unmodifiable(unique.values);
  }
  final bool Function(Channel) _allowed;
  late final List<Channel> playlist;
  Channel current;
  bool busy = false;
  bool _disposed = false;
  int _operation = 0;
  CastConnectionObserver? _connectionObserver;
  String? confirmedContentId;
  String? deviceName;
  Future<String> Function(Channel)? _castLoader;
  bool get casting => _castLoader != null;
  List<Channel> get available =>
      playlist.where(_allowed).toList(growable: false);
  bool get canChange => !_disposed && !busy && available.length > 1;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> startCasting(
    Future<String> Function(Channel) loader, {
    Stream<bool>? connectionStates,
    bool Function()? isDisconnected,
    VoidCallback? onDisconnected,
  }) async {
    if (_disposed || busy) return false;
    final operation = ++_operation;
    busy = true;
    _changed();
    try {
      if (connectionStates != null) {
        _connectionObserver?.dispose();
        _connectionObserver = CastConnectionObserver(
          connectionStates,
          isDisconnected: isDisconnected,
          onDisconnected: () {
            stopCasting();
            onDisconnected?.call();
          },
        );
        if (_disposed || operation != _operation) return false;
      }
      final id = await loader(current);
      if (_disposed || operation != _operation) return false;
      _castLoader = loader;
      confirmedContentId = id;
      return true;
    } catch (_) {
      if (_disposed || operation != _operation) return false;
      _connectionObserver?.dispose();
      _connectionObserver = null;
      rethrow;
    } finally {
      if (!_disposed && operation == _operation) {
        busy = false;
        _changed();
      }
    }
  }

  void stopCasting() {
    if (_disposed) return;
    ++_operation;
    _connectionObserver?.dispose();
    _connectionObserver = null;
    busy = false;
    _castLoader = null;
    confirmedContentId = null;
    deviceName = null;
    _changed();
  }

  Future<void> select(Channel channel) async {
    if (_disposed ||
        busy ||
        channel.url == current.url ||
        !_allowed(channel) ||
        !playlist.any((c) => c.url == channel.url)) {
      return;
    }
    final operation = ++_operation;
    busy = true;
    _changed();
    try {
      final loader = _castLoader;
      final id = loader == null ? null : await loader(channel);
      if (_disposed || operation != _operation) return;
      current = channel;
      confirmedContentId = id;
    } finally {
      if (!_disposed && operation == _operation) {
        busy = false;
        _changed();
      }
    }
  }

  Future<void> step(int direction) async {
    final channels = available;
    if (_disposed || busy || channels.length < 2) return;
    final index = channels.indexWhere((c) => c.url == current.url);
    final next = index < 0
        ? (direction > 0 ? 0 : channels.length - 1)
        : (index + direction) % channels.length;
    await select(channels[next]);
  }

  @override
  void dispose() {
    _disposed = true;
    ++_operation;
    _connectionObserver?.dispose();
    _connectionObserver = null;
    busy = false;
    _castLoader = null;
    confirmedContentId = null;
    deviceName = null;
    super.dispose();
  }
}
