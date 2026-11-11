import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/sports/caze_tv_embed.dart';
import 'package:rocha_plus/src/sports/caze_tv_playback.dart';

void main() {
  String event(String kind, {int session = 1, int? value}) =>
    jsonEncode({'event': kind, 'session': session, 'value': value});

  test('readiness never claims playback; state comes from the official player', () {
    final status = CazeTvPlayback();
    expect(status.ready, isFalse);
    expect(status.state, isNull);
    status.accept(event('ready'), 1);
    expect(status.label, 'Player pronto. Toque em reproduzir.');
    expect(status.state, isNull);
    status.accept(event('state', value: 3), 1);
    expect(status.buffering, isTrue);
    status.accept(event('state', value: 1), 1);
    expect(status.label, 'Reproduzindo pelo YouTube');
    expect(status.buffering, isFalse);
    status.accept(event('state', value: 2), 1);
    expect(status.label, 'Reprodução pausada');
    status.accept(event('state', value: 0), 1);
    expect(status.label, 'Reprodução encerrada');
  });

  test('embed errors clear playback and remain until retry', () {
    for (final code in [2, 5, 100, 101, 150, 153, 999]) {
      final status = CazeTvPlayback();
      status.accept(event('state', value: 1), 1);
      expect(status.accept(event('error', value: code), 1), isTrue);
      expect(status.state, isNull);
      expect(status.errorCode, code);
      expect(status.accept(event('state', value: 1), 1), isFalse);
      status.reset();
      expect(status.errorCode, isNull);
      expect(status.ready, isFalse);
      expect(status.state, isNull);
    }
    expect(CazeTvPlayback.errorMessage(101), contains('não permite'));
    expect(CazeTvPlayback.errorMessage(153), contains('identificação'));
  });

  test('stale, malformed and unknown events cannot change a new session', () {
    final status = CazeTvPlayback();
    for (final message in [
      'invalid', '[]', '{}', event('state', session: 1, value: 1),
      event('state', session: 2, value: 99), event('unknown', session: 2),
      '{"session":2,"event":"error","value":"153"}',
    ]) {
      expect(status.accept(message, 2), isFalse);
    }
    expect(status.ready, isFalse);
    expect(status.state, isNull);
    expect(status.errorCode, isNull);
  });

  test('embed wrapper rejects injection and uses official events and app identity', () {
    expect(() => CazeTvEmbed.html('<script>bad', 1), throwsArgumentError);
    expect(() => CazeTvEmbed.html('abcdefghijk', 0), throwsArgumentError);
    final html = CazeTvEmbed.html('abcdefghijk', 2);
    expect(html, contains('https://www.youtube.com/iframe_api'));
    expect(html, contains('https://com.rochaplus.app'));
    expect(html, contains('strict-origin-when-cross-origin'));
    expect(html, contains('controls: 1'));
    expect(html, contains('autoplay: 0'));
    expect(html, contains('onReady:'));
    expect(html, contains('onStateChange:'));
    expect(html, contains('onError:'));
    expect(html, contains('session: 2'));
  });
}
