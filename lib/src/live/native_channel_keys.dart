import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native CH keys are consumed by Android only while a player owns this bridge.
/// Other platforms/remotes continue using the Flutter keyboard focus handler.
class NativeChannelKeys {
  static const channel = MethodChannel('com.rochaplus.app/channel_keys');
  static NativeChannelKeys? _active;
  final ValueChanged<int> onStep;

  NativeChannelKeys(this.onStep);

  static Future<void> _receive(MethodCall call) async {
    final active = _active;
    if (active != null && call.method == 'switch' &&
        (call.arguments == 1 || call.arguments == -1)) {
      active.onStep(call.arguments as int);
    }
  }

  Future<bool> activate() async {
    _active = this;
    channel.setMethodCallHandler(_receive);
    try {
      await channel.invokeMethod<void>('setEnabled', true);
      return identical(_active, this);
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> deactivate() async {
    if (!identical(_active, this)) return;
    _active = null;
    // Keep a static receiver to discard late events instead of buffering them
    // for the next player. It retains no disposed player or widget callback.
    try {
      await channel.invokeMethod<void>('setEnabled', false);
    } on MissingPluginException {
      // Flutter keyboard handling remains available on non-Android platforms.
    } on PlatformException {
      // Activity/engine may already be detaching during route disposal.
    }
  }
}
