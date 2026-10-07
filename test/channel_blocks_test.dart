import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel_blocks.dart';
import 'package:rocha_plus/src/live/channel_identity.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('stored block survives a fresh repository and quality suffix changes', () async {
    await ChannelBlocks().block('  TV Encontro das Águas (720p) ');
    final names = await ChannelBlocks().load();
    expect(names, contains(channelIdentity('TV Encontro das Aguas (1080p)')));
    await ChannelBlocks().clear();
    expect(await ChannelBlocks().load(), isEmpty);
  });
}
