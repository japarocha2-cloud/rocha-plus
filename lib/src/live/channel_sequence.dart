import 'channel.dart';

/// Snapshot of the list the viewer opened, including category/search/favorites.
class ChannelSequence {
  final List<Channel> channels;
  int _index;

  ChannelSequence(Channel selected, Iterable<Channel> lineup)
      : channels = List.unmodifiable(_unique(selected, lineup)), _index = 0 {
    _index = channels.indexWhere((c) => c.url == selected.url);
  }

  static List<Channel> _unique(Channel selected, Iterable<Channel> lineup) {
    final seen = <String>{};
    final result = lineup.where((c) => seen.add(c.url)).toList();
    if (seen.add(selected.url)) result.add(selected);
    return result;
  }

  Channel get current => channels[_index];

  void move(int direction) {
    _index = (_index + direction) % channels.length;
  }
}
