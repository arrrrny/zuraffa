// SPEC 1568 — the run driver parks make hand-steps (non-fatal) and
// never re-drives them on resume.
//
// The driver pins for the make `outcome=hand-step` verdict (the
// planner-declared entity-return seam, issue #1568):
//   d1 — the summary line carries `hand_steps=N` (the `skipped-widget=`
//        precedent) for non-empty id lists;
//   d2 — the park arm: the behavior keeps PENDING, the id is persisted,
//        and the run CONTINUES — the mechanical behaviors behind the
//        hand-step are reachable and drive to their own verdicts;
//   d3 — resume does not re-drive a known hand-step (the parked line,
//        no step spawn);
//   d4 — the end-of-run terminal block names the ids with the
//        deliberate-implementation remedy.
//
// Fast tier throughout: the fake zfa scripts every step, no `dart test`
// spawn (kernel-cache-safe fixture rule) — the bug_1544 convention.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/commands/run_driver_core.dart';

import '../helpers/tdd_fixture.dart';

/// Reads the process-global `dart:io exitCode` and immediately resets it
/// (the same suite-wide flake guard bug_1544 uses).
int takeExitCode() {
  final code = exitCode;
  exitCode = 0;
  return code;
}

Map<String, dynamic> readStateJson(TddFixture fx) =>
    jsonDecode(File(fx.runStatePath).readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('C-1568-d1: summaryLine hand_steps token', () {
    test('a non-empty hand-step list emits ` hand_steps=N`', () {
      final line = RunDriverCore.summaryLine(
        label: 'run',
        feature: '004-login-ui',
        result: 'stopped',
        counts: const {
          'total': 2,
          'pending': 1,
          'red': 0,
          'green': 0,
          'done': 1,
        },
        handStepIds: const ['U1', 'U7'],
      );
      expect(line, contains('hand_steps=2'));
    });

    test('an empty hand-step list emits nothing (byte-for-byte legacy '
        'shape)', () {
      final line = RunDriverCore.summaryLine(
        label: 'run',
        feature: '004-login-ui',
        result: 'complete',
        counts: const {
          'total': 1,
          'pending': 0,
          'red': 0,
          'green': 0,
          'done': 1,
        },
        handStepIds: const [],
      );
      expect(line, isNot(contains('hand_steps')));
    });
  });

  group('run: make hand-steps are parked, not run-fatal (issue #1568)', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create(
        featureName: '004-login-ui',
        writeProfile: false,
      );
      await fx.writeFakeZfa();
      // U1 is the planner-declared hand-step (the entity-return contract
      // subject); U2 is the MECHANICAL behavior behind it — the bug made
      // U2 unreachable (the run stopped at U1's make on every resume).
      await fx.seedTestList([
        (
          id: 'U1',
          description: 'the scanner exposes the active session',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'U2',
          description: 'the counter exposes the total',
          traces: 'FR-002',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.setStepOutcome('make', 'U1', 'hand-step');
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    test('d2: a hand-step make parks the behavior and the run drives the '
        'mechanical behaviors behind it', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        '004-login-ui',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      // The park arm names the outcome and the issue (an actionable,
      // honest verdict — never a silent regrade).
      expect(out, contains('outcome=hand-step'), reason: out);
      expect(out, contains('#1568'), reason: out);
      expect(out, contains('U1:hand'), reason: out);

      // U2 was REACHED and driven to done (the bug: it never was —
      // every run stopped at U1's make).
      expect(
        fx.stepInvocations(),
        containsAllInOrder([
          'make U1',
          'gen U2',
          'verify-red U2',
          'make U2',
          'refactor U2',
        ]),
      );

      // The hand-step behavior keeps its honest state — the make NEVER
      // advances it past the state it drove to (verify-red certified the
      // honest RED; the pre-#1568 wall instead left it wedged at the
      // stopped run): never a fake green/done, red evidence standing.
      // AC-4's "stay pending with honest red" is the not-advanced state:
      // a behavior the make parks before any advance stays PENDING, one
      // whose verify-red certified first stays RED.
      final states = readStateJson(fx)['behavior_states'] as Map;
      expect(states['U1'], 'red');
      expect(states['U2'], 'done');

      // AC-4's persistence basis: the hand-step id is recorded.
      expect(
        (readStateJson(fx)['hand_steps'] as List?) ?? <String>[],
        contains('U1'),
      );

      // The run reports bounded progress, not a wall: the summary names
      // the hand-step count, the terminal block names the id (d4).
      expect(out, contains('hand_steps=1'), reason: out);
      expect(out, contains('hand-step for U1'), reason: out);
      expect(out, contains('implement each subject deliberately'), reason: out);
      expect(out, contains('result=stopped'), reason: out);
      expect(takeExitCode(), 1, reason: out);
    });

    test('d3: resume does not re-drive a known hand-step behavior', () async {
      final runner = CliRunner(exitOnCompletion: false);
      // Run 1: U1 parks, U2 drives to done.
      await runner.runCapturing([
        'tdd',
        'run',
        '004-login-ui',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);
      takeExitCode();
      fx.clearStepInvocations();

      // Run 2 (resume): U1 must be SKIPPED — not re-driven.
      final out = await runner.runCapturing([
        'tdd',
        'run',
        '004-login-ui',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      expect(
        out,
        contains('U1 make -> parked (planner-declared hand-step'),
        reason: out,
      );
      expect(fx.stepInvocations(), isNot(contains('gen U1')), reason: out);
      expect(
        fx.stepInvocations(),
        isNot(contains('verify-red U1')),
        reason: out,
      );
      expect(fx.stepInvocations(), isNot(contains('make U1')), reason: out);
      // The behavior stays honestly red with its red evidence.
      expect(readStateJson(fx)['behavior_states']['U1'], 'red');
      expect(takeExitCode(), 1, reason: out);
    });
  });
}
