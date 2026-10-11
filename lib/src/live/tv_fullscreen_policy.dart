import 'package:flutter/material.dart';

/// Chooses TV-style playback without changing normal phone playback.
///
/// Flutter's directional navigation mode is the preferred signal for remotes.
/// Some Android TV firmware reports traditional navigation, so a wide
/// landscape display with a TV-sized shortest side is a fallback. This is a
/// presentation heuristic, not a guarantee that a device is Android TV.
bool shouldStartTvFullscreen(MediaQueryData media, TargetPlatform platform) {
  if (platform != TargetPlatform.android) return false;
  if (media.navigationMode == NavigationMode.directional) return true;

  return media.orientation == Orientation.landscape &&
      media.size.width >= 900 &&
      media.size.shortestSide >= 500;
}
