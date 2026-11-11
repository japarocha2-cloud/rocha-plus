import 'dart:convert';
import 'caze_tv_source.dart';

/// Our own wrapper around the official API; no media URLs or third-party HTML.
class CazeTvEmbed {
  const CazeTvEmbed._();

  static String html(String id, int session) {
    if (!CazeTvSource.isValidVideoId(id) || session < 1) {
      throw ArgumentError('Invalid embed session');
    }
    final video = jsonEncode(id);
    final origin = jsonEncode(Uri.parse(CazeTvSource.appHttpReferer).origin);
    return '''
<!doctype html>
<html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>
html,body{margin:0;padding:0;width:100%;height:100%;background:#000}
#player{width:100%;height:100%}
</style>
</head><body>
<div id="player"></div>
<script>
function report(event, value) {
  RochaYouTube.postMessage(JSON.stringify({
    session: $session, event: event, value: value
  }));
}
function onYouTubeIframeAPIReady() {
  new YT.Player('player', {
    width: '100%', height: '100%', videoId: $video,
    playerVars: {controls: 1, playsinline: 1, autoplay: 0, origin: $origin},
    events: {
      onReady: function() { report('ready', null); },
      onStateChange: function(e) { report('state', e.data); },
      onError: function(e) { report('error', e.data); }
    }
  });
}
</script>
<script src="https://www.youtube.com/iframe_api"></script>
</body></html>
''';
  }
}
