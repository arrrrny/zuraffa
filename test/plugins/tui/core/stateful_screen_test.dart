import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tui/core/stateful_screen.dart';

void main() {
  group('StatefulScreen (FR-003, SC-002)', () {
    test(
      'A5 / U8: setState triggers a re-render with the new value',
      () async {
        final tester = await nocterm.NoctermTester.create(size: const nocterm.Size(40, 5));
        addTearDown(tester.dispose);

        await tester.pumpComponent(const _CounterScreen());
        await tester.pump();

        // Initial state shows count 0.
        expect(tester.terminalState.getText(), contains('count: 0'));

        // Pump a key that increments.
        await tester.sendKey(nocterm.LogicalKey.fromCharacter('j')!);

        // After re-render, count should be 1.
        expect(tester.terminalState.getText(), contains('count: 1'));

        // A second increment to 2.
        await tester.sendKey(nocterm.LogicalKey.fromCharacter('j')!);
        expect(tester.terminalState.getText(), contains('count: 2'));
      },
    );

    test(
      'U8 (continued): setState preserves unrelated state — only the '
      'affected view is invalidated',
      () async {
        final tester = await nocterm.NoctermTester.create(size: const nocterm.Size(40, 5));
        addTearDown(tester.dispose);

        await tester.pumpComponent(const _CounterScreen());
        await tester.pump();

        // Both the static label and the count are rendered initially.
        expect(tester.terminalState.getText(), contains('count: 0'));
        expect(tester.terminalState.getText(), contains('press j to increment'));

        // Increment — the static label should still be present after re-render.
        await tester.sendKey(nocterm.LogicalKey.fromCharacter('j')!);
        expect(tester.terminalState.getText(), contains('count: 1'));
        expect(tester.terminalState.getText(), contains('press j to increment'));
      },
    );
  });
}

class _CounterScreen extends StatefulScreen {
  const _CounterScreen();

  @override
  TuiScreenState<_CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends TuiScreenState<_CounterScreen> {
  int _count = 0;

  @override
  nocterm.Component buildScreen(nocterm.BuildContext context) {
    return nocterm.Center(
      child: nocterm.Column(
        children: [
          nocterm.Text('count: $_count'),
          const nocterm.Text('press j to increment'),
        ],
      ),
    );
  }

  @override
  void onKey(nocterm.KeyboardEvent event) {
    if (event.logicalKey == nocterm.LogicalKey.fromCharacter('j')) {
      _count++;
      setState(() {});
    }
  }
}
