import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/channel_sequence.dart';

const a = Channel(name: 'Infantil A', url: 'https://example.com/a');
const b = Channel(name: 'Infantil B', url: 'https://example.com/b');
const c = Channel(name: 'Infantil C', url: 'https://example.com/c');

void main() {
  test('zapping starts at the selected channel and wraps both ends', () {
    final sequence = ChannelSequence(b, [a, b, c]);
    expect(sequence.current, b);
    sequence.move(1);
    expect(sequence.current, c);
    sequence.move(1);
    expect(sequence.current, a);
    sequence.move(-1);
    expect(sequence.current, c);
  });
  test('a category/favorite snapshot never imports channels from elsewhere', () {
    final source = [b, c];
    final sequence = ChannelSequence(c, source);
    source.add(a);
    sequence.move(1);
    expect(sequence.current, b);
    expect(sequence.channels, [b, c]);
  });
  test('empty and duplicate lists cannot create missing or repeated channels', () {
    final one = ChannelSequence(a, []);
    one.move(-1);
    expect(one.current, a);
    final deduplicated = ChannelSequence(b, [a, a, b]);
    expect(deduplicated.channels, [a, b]);
    deduplicated.move(1);
    expect(deduplicated.current, a);
  });
}
