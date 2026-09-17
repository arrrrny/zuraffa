@Tags(['slow'])
// Issue #1568 — `tdd make` hard-stops with generation-error on behaviors
// the planner already declared HAND-STEP (entity-return contract
// subjects), making every mechanical behavior behind them unreachable.
//
// The subject of such a behavior is a gen contract-derived stub
// (`ScanSession scan() => throw UnimplementedError(…)`, issue #1259) and
// there is no generated implementation step for an entity-returning
// contract subject — so the target test failing "after generation" is
// the expected, PRE-DECLARED hand-step state, not a generation defect.
// The pre-fix driver graded it `generation-error` and stopped the whole
// run at the first hand-step (the #1544 hard-stop family).
//
// The fix (run driver only — make, the planner and the state machine are
// untouched): a make failure whose TWO signals agree — the behavior is
// in the seam-cost forecast (SPEC 1489, the planner's own hand-step
// verdict) AND make's transcript carries the still-failing-target-test
// shape — parks the behavior at its honest red, the pass CONTINUES with
// the remaining behaviors, and the end-of-pass summary names the
// hand-steps (`hand_steps=N`, `stopped_at=<id>:hand`). Any other
// generation-error (a real generation bug, marker absent, non-seam
// behavior) keeps the honest generic stop.
//
// Fast tier throughout: the fake zfa scripts every step, no `dart test`
// spawn (kernel-cache-safe fixture rule).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

/// The declared-contract spec: `ScanService.scan() -> ScanSession` — the
/// return is an entity the registry does NOT declare (the fixture writes
/// no entity file), so the resolved seam forecast marks U1 hand-step.
const specWithEntityReturnContract = '''
**Template Version**: `zuraffa-1.0`

# Spec: 008-scan

### Layer Contracts

**Domain**:
- `ScanService`: `scan() -> ScanSession`

## Functional Requirements

- **FR-001**: System MUST expose the scan session
            traces: ScanService
- **FR-002**: System MUST expose the scan summary
            traces: SummaryService

## Acceptance Scenarios

1. **Given** a scan **When** the session is read **Then** the session is exposed.
''';

void main() {
  group('run: planner-declared hand-steps park, not stop (issue #1568)', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create(
        featureName: '008-scan',
        writeProfile: false,
      );
      await fx.writeFakeZfa();
      await File(
        p.join(fx.featureDir, 'spec.md'),
      ).writeAsString(specWithEntityReturnContract);
      // U1: the entity-return contract subject (the hand-step seam).
      // U2: a plain unit behavior (traces resolve to no declared row →
      // never a seam) that must stay reachable behind U1's hand-step.
      await fx.seedTestList([
        (
          id: 'U1',
          description: 'scan returns the session (entity-return subject)',
          traces: 'ScanService.scan',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'U2',
          description: 'the summary is exposed (plain scalar unit)',
          traces: 'FR-002',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    test('U-1568-1: a seam behavior make failure parks U1 and the run '
        'still drives U2; the summary names the hand step', () async {
      await fx.setStepOutcome('make', 'U1', 'hand-step-red');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        '008-scan',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      // U1 parked at the NAMED hand step — not the generic make stop.
      expect(
        out,
        contains('hand step: U1:hand'),
        reason: 'the park names the designed hand step, output:\n$out',
      );
      expect(out, contains('hand_steps=1'));
      expect(out, contains('stopped_at=U1:hand'));
      expect(out, contains('hand-step for U1'));

      // THE BUG: U2 was REACHED and driven behind U1's hand-step — the
      // pre-fix driver stopped the run AT U1 and U2 was unreachable.
      expect(
        fx.stepInvocations(),
        containsAllInOrder(['make U1', 'gen U2']),
        reason:
            'the mechanical behavior behind the hand-step must be '
            'driven in the same run, invocations:\n'
            '${fx.stepInvocations().join('\n')}',
      );

      // Review fix: the parked stop carries the park's OWN journal
      // vocabulary. The #1308 `hand-step=<id>:hand — …` remedy
      // prescribes replacing a guard the generated entity-return
      // subject need not contain, so `_handStepViolationFor` (which
      // ALWAYS returns a string — its fallback is the vacuous-guard
      // remedy) must stand down for the behavior this pass parked.
      final journal = _journalText(fx);
      expect(journal, contains('parked-hand-step=U1'));
      expect(
        journal,
        isNot(contains('hand-step=U1:hand')),
        reason:
            'the #1308 vacuous-guard remedy must not fire for a park, '
            'journal:\n$journal',
      );
    });

    test('U-1568-4: a LATER behavior\'s real generation failure keeps the '
        'parked hand-step on record', () async {
      // Review fix: the in-loop stop paths used to call `_finish`
      // without the parked set, so a pass that parked U1 and then
      // stopped for an unrelated U2 lost both `hand_steps=N` from the
      // summary line and the journal's park record.
      await fx.setStepOutcome('make', 'U1', 'hand-step-red');
      await fx.setStepOutcome('make', 'U2', 'crash-no-marker');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        '008-scan',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      expect(out, contains('hand step: U1:hand'));
      expect(
        out,
        contains('stopped_at=U2:make'),
        reason:
            'U2 has no still-failing marker — the honest generic stop '
            'stands, output:\n$out',
      );
      expect(
        out,
        contains('hand_steps=1'),
        reason:
            'the parked hand-step must survive a later unrelated stop, '
            'output:\n$out',
      );

      final journal = _journalText(fx);
      expect(
        journal,
        contains('parked-hand-step=U1'),
        reason:
            'the journal must still record the behavior this pass '
            'deliberately parked, journal:\n$journal',
      );
    });

    test('U-1568-2: a REAL generation failure on a seam behavior (no '
        'still-failing marker) keeps the honest generic stop', () async {
      await fx.setStepOutcome('make', 'U1', 'crash-no-marker');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        '008-scan',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      expect(
        out,
        contains('stopped_at=U1:make'),
        reason:
            'without the pre-declared red shape the generic stop '
            'stands (safe failure), output:\n$out',
      );
      expect(out, isNot(contains('hand step: U1:hand')));
      expect(out, isNot(contains('hand_steps=')));
      expect(
        fx.stepInvocations(),
        isNot(contains('gen U2')),
        reason: 'a real generation error still stops the run',
      );
    });

    test('U-1568-3: the still-failing marker on a NON-seam behavior '
        'never parks — the generic stop stands', () async {
      await fx.setStepOutcome('make', 'U2', 'hand-step-red');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        '008-scan',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      expect(
        out,
        contains('stopped_at=U2:make'),
        reason:
            'the forecast must gate the park — a marker without the '
            'planner verdict is still a real generation error, '
            'output:\n$out',
      );
      expect(out, isNot(contains('hand_steps=')));
    });
  });
}

/// The feature's unified journal as raw text — the violation lines are
/// asserted as substrings, so the raw JSON is enough (no decode, no
/// escaping surprises in the ASCII park vocabulary).
String _journalText(TddFixture fx) =>
    File(p.join(fx.featureDir, 'tdd', 'journal.json')).readAsStringSync();
