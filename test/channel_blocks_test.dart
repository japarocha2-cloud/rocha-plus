import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel_blocks.dart';
import 'package:rocha_plus/src/live/channel_identity.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChannelBlocks.resetForTests();
  });
  test('stored block survives a fresh repository and quality suffix changes', () async {
    await ChannelBlocks().block('  TV Encontro das Águas (720p) ');
    final names = await ChannelBlocks().load();
    expect(names, contains(channelIdentity('TV Encontro das Aguas (1080p)')));
    await ChannelBlocks().clear();
    expect(await ChannelBlocks().load(), isEmpty);
  });
  test('concurrent removals do not overwrite each other', () async {
    await Future.wait([ChannelBlocks().block('Canal A'), ChannelBlocks().block('Canal B')]);
    expect(await ChannelBlocks().load(), containsAll(['canal a', 'canal b']));
  });
  test('restoring hidden names does not restore rejected URLs', () async {
    await ChannelBlocks().block('Canal');
    await ChannelBlocks().blockUrl('https://example.com/broken');
    await ChannelBlocks().clear();
    expect(await ChannelBlocks().load(), isEmpty);
    expect(await ChannelBlocks().loadUrls(), contains('https://example.com/broken'));
  });
}
