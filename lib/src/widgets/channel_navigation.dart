import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../live/channel_playback_session.dart';

/// CH+/CH- and PageUp/PageDown change channels; arrows retain focus traversal.
class ChannelNavigation extends StatelessWidget {
  final ChannelPlaybackSession session;
  final Widget child;
  const ChannelNavigation({
    super.key,
    required this.session,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      final key = event.logicalKey;
      final direction =
          key == LogicalKeyboardKey.channelUp ||
              key == LogicalKeyboardKey.pageUp
          ? 1
          : key == LogicalKeyboardKey.channelDown ||
                key == LogicalKeyboardKey.pageDown
          ? -1
          : 0;
      if (direction == 0) return KeyEventResult.ignored;
      change(context, session, direction);
      return KeyEventResult.handled;
    },
    child: child,
  );
  static Future<void> change(
    BuildContext context,
    ChannelPlaybackSession session,
    int direction,
  ) async {
    try {
      await session.step(direction);
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível trocar de canal. Tente novamente.'),
          ),
        );
    }
  }
}

class ChannelStepButtons extends StatelessWidget {
  final ChannelPlaybackSession session;
  const ChannelStepButtons({super.key, required this.session});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Canal anterior',
          onPressed: session.canChange
              ? () => ChannelNavigation.change(context, session, -1)
              : null,
          icon: const Icon(Icons.skip_previous),
        ),
        IconButton(
          tooltip: 'Próximo canal',
          onPressed: session.canChange
              ? () => ChannelNavigation.change(context, session, 1)
              : null,
          icon: const Icon(Icons.skip_next),
        ),
      ],
    ),
  );
}
