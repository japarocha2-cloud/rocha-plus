import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/widgets/player_controls_focus.dart';

void main() {
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
