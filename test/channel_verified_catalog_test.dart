import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/channel.dart';

void main() {
  setUp(ChannelRepository.resetSessionHealthForTests);

  const approved = Channel(name: 'Canal Validado', url: 'https://example.org/approved.m3u8', group: 'Esportes');
  const unverified = Channel(name: 'Canal Nao Testado', url: 'https://example.org/unverified.m3u8', group: 'Esportes');

  test('demo mode hides any unapproved channel', () {
    final repository = ChannelRepository(verifiedOnly: true, approvedUrls: {approved.url});
    expect(repository.sportsOnly([approved, unverified]), [approved]);
  });

  test('demo mode fails closed when no playback evidence was approved', () {
    final repository = ChannelRepository(verifiedOnly: true, approvedUrls: {});
    expect(repository.sportsOnly([approved, unverified]), isEmpty);
  });

  test('failed playback still quarantines previously approved stream', () {
    final repository = ChannelRepository(verifiedOnly: true, approvedUrls: {approved.url});
    repository.reportPlaybackFailure(approved.url);
    expect(repository.sportsOnly([approved]), isEmpty);
  });

  test('standard mode remains unchanged', () {
    final repository = ChannelRepository(verifiedOnly: false, approvedUrls: {});
    expect(repository.sportsOnly([approved, unverified]), [approved, unverified]);
  });
}
