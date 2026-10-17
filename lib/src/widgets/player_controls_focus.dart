import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlayerControlsFocus extends StatelessWidget {
  final bool controlsVisible;
  final VoidCallback onShowControls;
  final ValueChanged<int>? onChannelStep;
  final Widget child;
  const PlayerControlsFocus({
    super.key, required this.controlsVisible, required this.onShowControls,
    required this.child, this.onChannelStep,
  });
  @override
  Widget build(BuildContext context) => Focus(
    autofocus: onChannelStep != null,
    canRequestFocus: onChannelStep != null,
    skipTraversal: true,
    onKeyEvent: (_, event) {
      final key = event.logicalKey;
      final next = key == LogicalKeyboardKey.channelUp || key == LogicalKeyboardKey.pageUp ||
          (!controlsVisible && key == LogicalKeyboardKey.arrowUp);
      final previous = key == LogicalKeyboardKey.channelDown || key == LogicalKeyboardKey.pageDown ||
          (!controlsVisible && key == LogicalKeyboardKey.arrowDown);
      if (onChannelStep != null && (next || previous)) {
        // One switch per press. A held key must not create dozens of decoders.
        if (event is KeyDownEvent) onChannelStep!(next ? 1 : -1);
        return KeyEventResult.handled;
      }
      const keys = [
        LogicalKeyboardKey.enter, LogicalKeyboardKey.select,
        LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowRight,
      ];
      if (!controlsVisible && event is KeyDownEvent && keys.contains(event.logicalKey)) {
        onShowControls();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: child,
  );
}
