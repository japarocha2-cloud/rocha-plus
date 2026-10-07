import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/cast/cast_playback_evidence.dart';

void main() {
  test('stale playback of a different channel cannot confirm a new request', () {
    expect(CastPlaybackEvidence.confirms(requested: 'https://example.com/new',
      contentId: 'https://example.com/old', playing: true), isFalse);
    expect(CastPlaybackEvidence.confirms(requested: 'https://example.com/new',
      contentId: 'https://example.com/new', playing: false), isFalse);
    expect(CastPlaybackEvidence.confirms(requested: 'https://example.com/new',
      contentId: 'https://example.com/new', playing: true), isTrue);
  });
  test('receiver URL can identify media when content ID is absent', () {
    expect(CastPlaybackEvidence.confirms(requested: 'https://example.com/new',
      contentUrl: Uri.parse('https://example.com/new'), playing: true), isTrue);
    expect(CastPlaybackEvidence.confirms(requested: 'https://example.com/new',
      playing: true), isFalse);
  });
}
