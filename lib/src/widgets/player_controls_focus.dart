import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlayerControlsFocus extends StatelessWidget {
  final bool controlsVisible;
  final VoidCallback onShowControls;
  final Widget child;
  const PlayerControlsFocus({
    super.key, required this.controlsVisible, required this.onShowControls,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: (_, event) {
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
