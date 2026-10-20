import 'package:flutter/foundation.dart';

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
  String? confirmedContentId;
  String? deviceName;
  Future<String> Function(Channel)? _castLoader;
  bool get casting => _castLoader != null;
  List<Channel> get available =>
      playlist.where(_allowed).toList(growable: false);
  bool get canChange => !busy && available.length > 1;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> startCasting(Future<String> Function(Channel) loader) async {
    if (busy) return;
    busy = true;
    _changed();
    try {
      final id = await loader(current);
      _castLoader = loader;
      confirmedContentId = id;
    } finally {
      busy = false;
      _changed();
    }
  }

  void stopCasting() {
    _castLoader = null;
    confirmedContentId = null;
    _changed();
  }

  Future<void> select(Channel channel) async {
    if (busy ||
        channel.url == current.url ||
        !_allowed(channel) ||
        !playlist.any((c) => c.url == channel.url)) {
      return;
    }
    busy = true;
    _changed();
    try {
      final loader = _castLoader;
      final id = loader == null ? null : await loader(channel);
      current = channel;
      confirmedContentId = id;
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> step(int direction) async {
    final channels = available;
    if (busy || channels.length < 2) return;
    final index = channels.indexWhere((c) => c.url == current.url);
    final next = index < 0
        ? (direction > 0 ? 0 : channels.length - 1)
        : (index + direction) % channels.length;
    await select(channels[next]);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
