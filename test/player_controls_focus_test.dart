import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/widgets/player_controls_focus.dart';

void main() {
  testWidgets('CH keys always zap; arrows zap only with hidden controls', (tester) async {
    var visible = false;
    final steps = <int>[];
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (context, update) =>
      PlayerControlsFocus(
        controlsVisible: visible, onChannelStep: steps.add,
        onShowControls: () => update(() => visible = true),
        child: TextButton(autofocus: true, onPressed: () {}, child: const Text('Pausar')),
      ))));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(steps, [1]);
    expect(visible, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(visible, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(steps, [1]);
    await tester.sendKeyEvent(LogicalKeyboardKey.channelDown);
    expect(steps, [1, -1]);
  });
  testWidgets('holding CH does not create repeated channel loads', (tester) async {
    var switches = 0;
    await tester.pumpWidget(MaterialApp(home: PlayerControlsFocus(
      controlsVisible: false, onShowControls: () {}, onChannelStep: (_) => switches++,
      child: const SizedBox())));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.channelUp);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.channelUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.channelUp);
    expect(switches, 1);
  });
  testWidgets('first remote key reveals hidden controls before activating playback', (tester) async {
    var visible = false;
    var actions = 0;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (context, update) =>
      PlayerControlsFocus(
        controlsVisible: visible,
        onShowControls: () => update(() => visible = true),
        child: TextButton(autofocus: true, onPressed: () => actions++,
            child: const Text('Pausar')),
      ),
    )));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(visible, isTrue);
    expect(actions, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(actions, 1);
  });
}
