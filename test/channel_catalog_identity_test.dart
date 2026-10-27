import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel_identity.dart';

void main() {
  test('resolution tags do not create a new channel identity', () {
    expect(channelIdentity('SBT (720p)'), channelIdentity('SBT (1080p)'));
  });

  test('regional channels remain distinguishable', () {
    expect(channelIdentity('SBT Interior'), isNot(channelIdentity('SBT Nacional')));
    expect(channelIdentity('TV Morena'), isNot(channelIdentity('Globo')));
  });

  test('not-24/7 labels normalize without losing channel identity', () {
    expect(channelIdentity('Canal X [not 24/7]'), 'canal x');
  });
}
