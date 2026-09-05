/// Acceptance behaviors A1–A4 for the `TheaterScreen` TUI (spec
/// 1006-tdd-theater-replay-tui, tdd/test-list.md) — driven through
/// nocterm's `NoctermTester`, the same harness `test/plugins/tui/` uses.
///
/// The screen is fed the snapshot loaded by the REAL `TheaterData` loader
/// from a REAL fixture project (registry + test-list + cycle-log seeded
/// through `CycleLog.append` + #807 receipts), so what these tests render
/// is exactly what `zfa tdd theater 004-login-ui` renders on a TTY.
library;

import 'dart:io';

import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:test/test.dart';

import 'package:zuraffa/src/plugins/tdd/services/theater_data.dart';
import 'package:zuraffa/src/plugins/tdd/widgets/theater_screen.dart';

import 'theater_fixture.dart';

void main() {
  Future<TheaterSnapshot> loadSnapshot(TheaterFixture fx) =>
      TheaterData.load(feature: fx.featureName, projectRoot: fx.root.path);

  group('theater screen (A-rows)', () {
    test(
      'A1: the three panes render every behavior and the timeline',
      () async {
        final fx = await TheaterFixture.create();
        addTearDown(() => fx.root.delete(recursive: true));
        final snapshot = await loadSnapshot(fx);

        final tester = await nocterm.NoctermTester.create(
          size: const nocterm.Size(110, 30),
        );
        addTearDown(tester.dispose);

        await tester.pumpComponent(TheaterScreen(snapshot: snapshot));
        await tester.pump();

        final text = tester.terminalState.getText();

        // The header names the feature and the read-only contract.
        expect(text, contains(fx.featureName));
        expect(text, contains('read-only'));

        // Left pane: every registered behavior renders with its criterion
        // and proof status.
        expect(text, contains('A1'));
        expect(text, contains('A2'));
        expect(text, contains('A3'));
        expect(text, contains('FR-001'));
        expect(text, contains('FR-002'));
        expect(text, contains('FR-003'));
        expect(text, contains('green'));
        expect(text, contains('red'));
        expect(text, contains('pending'));

        // Right pane: the cycle-log timeline in file order.
        expect(text, contains('A1 (red)'));
        expect(text, contains('A1 (green)'));
        expect(text, contains('A2 (red)'));

        // Bottom pane: the live status line.
        expect(text, contains('behaviors=3'));
        expect(text, contains('green=1'));
        expect(text, contains('red=1'));
        expect(text, contains('cycles=3'));
        expect(text, contains('receipts=2'));
      },
    );

    test('A2: clicking a behavior shows the receipt', () async {
      final fx = await TheaterFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      final snapshot = await loadSnapshot(fx);

      final tester = await nocterm.NoctermTester.create(
        size: const nocterm.Size(110, 30),
      );
      addTearDown(tester.dispose);

      await tester.pumpComponent(TheaterScreen(snapshot: snapshot));
      await tester.pump();

      // Tap the A1 behavior card in the left pane (its id text).
      final a1 = tester.terminalState.findText('A1').first;
      await tester.tap(a1.x, a1.y);
      await tester.pump();

      final text = tester.terminalState.getText();
      // The receipt pane: derived action, evidence, and file lines.
      expect(text, contains('action: satisfied'));
      expect(text, contains('evidence:'));
      expect(text, contains('exit 0'));
      expect(text, contains('file:'));
      expect(text, contains(fx.subjectRel('A1')));
      // The #807 receipt backing is visible on the file line.
      expect(text, contains('create'));
      expect(text, contains('receipt-file:'));

      // The card expanded inline: A1's OWN description + paths in the
      // left pane (only the expanded card carries them; the narrow pane
      // wraps the prose across lines).
      expect(text, contains('desc:'));
      expect(text, contains('the login form renders email'));
      expect(text, contains('test:'));
      expect(text, contains('subject:'));
    });

    test('A3: clicking a cycle shows the diff', () async {
      final fx = await TheaterFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      final snapshot = await loadSnapshot(fx);

      final tester = await nocterm.NoctermTester.create(
        size: const nocterm.Size(110, 30),
      );
      addTearDown(tester.dispose);

      await tester.pumpComponent(TheaterScreen(snapshot: snapshot));
      await tester.pump();

      // Tap the first timeline row: 'A1 (red)'.
      final cycle = tester.terminalState.findText('A1 (red)').first;
      await tester.tap(cycle.x, cycle.y);
      await tester.pump();

      final text = tester.terminalState.getText();
      // The cycle's evidence diff: command, exit, captured output.
      expect(text, contains('command:'));
      expect(text, contains('exit: 1'));
      expect(text, contains('Expected: exactly 2 input fields'));
      // The red classification and recorded evidence.
      expect(text, contains('assertionFailure'));
      expect(text, contains('email and password fields render'));
      // The tamper-evident chain link is part of the diff view.
      expect(text, contains('hash:'));
    });

    test('A4: [?] opens the classifier verdict', () async {
      final fx = await TheaterFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      final snapshot = await loadSnapshot(fx);

      final tester = await nocterm.NoctermTester.create(
        size: const nocterm.Size(110, 30),
      );
      addTearDown(tester.dispose);

      await tester.pumpComponent(TheaterScreen(snapshot: snapshot));
      await tester.pump();

      // The selected behavior starts at A1 (first card). Press '?'.
      await tester.sendKey(nocterm.LogicalKey.question);
      await tester.pump();

      var text = tester.terminalState.getText();
      // The verdict overlay: classification label + remediation hint +
      // the recorded failing-assertion evidence.
      expect(text, contains('classifier verdict'));
      expect(text, contains('assertion'));
      expect(text, contains('email and password fields render'));

      // Any key closes the overlay.
      await tester.sendEscape();
      await tester.pump();
      text = tester.terminalState.getText();
      expect(text, isNot(contains('classifier verdict')));
    });

    test('A4b: keyboard navigation drives both panes honestly', () async {
      final fx = await TheaterFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      final snapshot = await loadSnapshot(fx);

      final tester = await nocterm.NoctermTester.create(
        size: const nocterm.Size(110, 30),
      );
      addTearDown(tester.dispose);

      await tester.pumpComponent(TheaterScreen(snapshot: snapshot));
      await tester.pump();

      // The status bar names the selected behavior and the focused pane.
      var text = tester.terminalState.getText();
      expect(text, contains('sel: A1 (behaviors)'));

      // Arrow down moves the behavior selection.
      await tester.sendArrowDown();
      await tester.pump();
      text = tester.terminalState.getText();
      expect(text, contains('sel: A2 (behaviors)'));

      // Enter activates the selected behavior: the card expands and the
      // right pane shows A2's receipt (red — its only evidence is red).
      await tester.sendEnter();
      await tester.pump();
      text = tester.terminalState.getText();
      expect(text, contains('action: red'));
      expect(text, contains('test:'));
      expect(text, contains('subject:'));

      // Escape returns the right pane to the timeline.
      await tester.sendEscape();
      await tester.pump();
      text = tester.terminalState.getText();
      expect(text, contains('A1 (red)'));

      // Tab moves focus to the timeline; the status bar names it.
      await tester.sendTab();
      await tester.pump();
      text = tester.terminalState.getText();
      expect(text, contains('(timeline)'));

      // Arrow right (from the left pane's perspective) is a no-op now;
      // arrow down moves the timeline selection to the second cycle.
      await tester.sendArrowDown();
      await tester.pump();
      await tester.sendEnter();
      await tester.pump();
      text = tester.terminalState.getText();
      // The second timeline row is A1's green entry with its generation
      // step and recorded command.
      expect(text, contains('cycle — A1 (green)'));
      expect(text, contains('zfa tdd gen A1 --feature 004-login-ui'));
      expect(text, contains('exit: 0'));

      // Escape returns to the timeline; arrowLeft/arrowRight switch the
      // focused pane back and forth (the same contract as Tab).
      await tester.sendEscape();
      await tester.pump();
      await tester.sendArrowLeft();
      await tester.pump();
      text = tester.terminalState.getText();
      expect(text, contains('sel: A2 (behaviors)'));
      await tester.sendArrowRight();
      await tester.pump();
      text = tester.terminalState.getText();
      expect(text, contains('(timeline)'));

      // Enter while the right pane shows a RECEIPT (not the timeline)
      // never activates a timeline row: the receipt view stays. (Tab
      // back to the behaviors, activate A2's receipt, then hand the
      // right pane focus and press Enter.)
      await tester.sendTab();
      await tester.pump();
      await tester.sendEnter();
      await tester.pump();
      text = tester.terminalState.getText();
      expect(text, contains('action: red'));
      await tester.sendTab();
      await tester.pump();
      text = tester.terminalState.getText();
      expect(text, contains('(timeline)'));
      await tester.sendEnter();
      await tester.pump();
      text = tester.terminalState.getText();
      expect(text, contains('action: red'));
      expect(text, isNot(contains('cycle — ')));

      // The '?' verdict follows the LEFT pane's selection (A2 — a load
      // error verdict).
      await tester.sendEscape();
      await tester.pump();
      await tester.sendKey(nocterm.LogicalKey.question);
      await tester.pump();
      text = tester.terminalState.getText();
      expect(text, contains('classifier verdict'));
      expect(text, contains('load-error'));
      // A2's red recorded no failing-assertion evidence line: the
      // overlay says so honestly instead of inventing one.
      await tester.sendEscape();
      await tester.pump();
    });

    test(
      'A3b: a cycle row with missing fields renders honest dashes',
      () async {
        final fx = await TheaterFixture.create(withCycleLog: false);
        addTearDown(() => fx.root.delete(recursive: true));
        await File(fx.cycleLogPath).writeAsString('''
# Cycle Log

## Cycle: A1 (red)

- behavior: A1
- kind: red
- criterion: FR-001
- command: `dart test test/login/a1_test.dart`
- exit: 1
- output:
```
Expected: exactly 2 input fields
```
''');
        final snapshot = await loadSnapshot(fx);

        final tester = await nocterm.NoctermTester.create(
          size: const nocterm.Size(110, 30),
        );
        addTearDown(tester.dispose);

        await tester.pumpComponent(TheaterScreen(snapshot: snapshot));
        await tester.pump();

        final row = tester.terminalState.findText('A1 (red)').first;
        await tester.tap(row.x, row.y);
        await tester.pump();

        final text = tester.terminalState.getText();
        // The missing test/at fields render the honest '-' placeholder,
        // never invented values and never a crash.
        expect(text, contains('test: -'));
        expect(text, contains('at: -'));
        expect(text, contains('command: dart test test/login/a1_test.dart'));
      },
    );

    test(
      'A1b: a feature with no cycle log renders the honest empty pane',
      () async {
        final fx = await TheaterFixture.create(withCycleLog: false);
        addTearDown(() => fx.root.delete(recursive: true));
        final snapshot = await loadSnapshot(fx);

        final tester = await nocterm.NoctermTester.create(
          size: const nocterm.Size(110, 30),
        );
        addTearDown(tester.dispose);

        await tester.pumpComponent(TheaterScreen(snapshot: snapshot));
        await tester.pump();

        final text = tester.terminalState.getText();
        expect(text, contains('(no cycle log at tdd/cycle-log.md)'));
        expect(text, contains('cycles=0'));
        // Every behavior still renders — as pending.
        expect(text, contains('A3'));
        expect(text, contains('pending'));
      },
    );
  });
}
