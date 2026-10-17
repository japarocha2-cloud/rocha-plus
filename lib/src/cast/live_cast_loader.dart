import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

/// Android uses an unassigned start time so the receiver chooses the live edge.
class LiveCastLoader {
  static const channel = MethodChannel('com.rochaplus.app/live_cast');
  static Future<void> load(GoogleCastMediaInformation media) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await channel.invokeMethod<void>('loadLive', {
        'url': media.contentUrl?.toString() ?? media.contentId,
        'title': media.metadata?.toMap()['title'] ?? 'Rocha+',
        'contentType': media.contentType,
      });
    } else {
      await GoogleCastRemoteMediaClient.instance.loadMedia(media, autoPlay: true);
    }
  }
}
