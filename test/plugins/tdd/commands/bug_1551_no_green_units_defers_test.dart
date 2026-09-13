// Bug #1551 — the acceptance compose precondition hard-stops the run.
//
// fix(1512) (commit 7d93b09) gave every acceptance row without an entity
// signal a REAL make surface: the spec-052 composition plan
// (`tdd compose <id> --feature <f>` → build). On a FRESH project the run
// driver walks behaviors in id order — A1 before any U* — so the compose
// step's anchor precondition ("at least one green/wired unit subject")
// is unmet at the first behavior. The compose command honestly fails
// with `outcome=no-green-units`, but the make graded that UNMET
// PRECONDITION as a `generation-error` (a generation defect), and the
// run driver's deferral arm (`unexpressible`/`no-op` → deferred
// (phase 2), the bug #625/#826 contract) cannot match it: the run
// hard-stops `result=stopped ... stopped_at=A1:make` and every resume
// re-stops identically — the deadlock.
//
// The fix (issue remedy 1 — "defer, don't stop"): when the failed
// generation step IS the plan's composition step and the child's output
// carries the compose summary line `outcome=no-green-units`, the make
// grades the behavior `unexpressible` — the exact token the pre-#1512
// zero-anchor shape produced — so the driver's EXISTING deferral arm
// defers the behavior to phase 2, where the units are green/wired and
// the composition succeeds. The compose command's own surface (its
// honest no-green-units stop for direct callers), the state machine,
// and the loop semantics are untouched; and a compose against GREEN
// anchors (the #1512 surface) still makes green.
//
// Pins (the bug_1512/bug_830 content-level convention: drive the public
// CLI surface in-process via CliRunner against a real temp fixture; the
// fixture root is passed via --project, never Directory.current):
//   (1) the #1551 mapping — make grades the compose no-green-units
//       precondition failure `unexpressible` (+ deferral message, no
//       `generation-error`, the #1036 subject-restore contract holds,
//       no green evidence);
//   (2) the deferral feeds the EXISTING loop arm — the make summary the
//       run driver parses is the bug-625 deferral token (pinned here at
//       the make surface; the loop side is pinned by
//       run_command_test.dart's bug 625/826 tests);
//   (3) a compose against GREEN anchors still makes green (the #1512
//       surface is unbroken — the "must not break" constraint);
//   (4) the direct `zfa tdd compose` surface keeps its honest
//       no-green-units stop (unchanged, exit 1, no rewrite);
//   (5) the remap's NEGATIVE boundary — the deferral is exclusive to
//       THIS behavior's `no-green-units` verdict: a compose failure
//       whose summary names any other outcome, and a `no-green-units`
//       summary naming a different behavior, both still grade
//       `generation-error`.
//
// Each make-driving pin spawns real `dart test` children inside the
// fixture (~40-50s per pin against the repo's global 2x ceiling of 60s,
// dart_test.yaml:49), so the file carries an explicit relaxed ceiling —
// at the default the pins sit right on the boundary and flake red on a
// loaded host (pin 3 failed outright at 60s before passing at 4x). 3
// minutes keeps the helper's 75s child-guard (run_zfa_source.dart, issue
// #531) comfortably shorter than the enclosing test's ceiling.
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

List<String> makeArgs(TddFixture fx, {String? id, String? zfaBin}) {
  final args = <String>['tdd', 'make', '--project', fx.root.path];
  if (zfaBin != null) args.addAll(['--zfa-bin', zfaBin]);
  if (id != null) args.add(id);
  return args;
}

List<String> composeArgs(TddFixture fx, {String? id}) {
  final args = <String>['tdd', 'compose', '--project', fx.root.path];
  if (id != null) args.add(id);
  return args;
}

/// The REAL `zfa tdd compose` failure transcript for a feature holding no
/// composable anchors (composition_targets.dart's fail-closed discovery
/// message + compose_command.dart's final summary line) — the exact child
/// output the make pipeline must classify (the issue's reproduction,
/// verbatim shape).
List<String> noGreenUnitsTranscript(String id, String feature) => [
  'zfa tdd compose: no green unit subjects to compose against: behavior '
      '"$id" needs at least one unit-kind behavior with green cycle-log '
      'evidence or an entity-wired subject artifact (the '
      '`wiredEntityAnchor` implementation anchor `zfa tdd wire` emits — '
      'issue #923: a wired unit subject is a valid composition anchor '
      'even while its behavior is still a stub). Wire a unit subject '
      'with `zfa tdd wire <id> --entity <Name>` or take a unit behavior '
      'green before composing against it.',
  'compose: behavior=$id outcome=no-green-units feature=$feature',
];

/// The fresh-project shape the issue reproduces: the acceptance row A1
/// certified red (gen wrote its stub; verify-red certified it), a unit
/// row U1 gen'd but NEVER driven — not green, not wired — and the driver
/// walks A1 first. Real discovery finds zero anchors.
Future<void> seedFreshProjectShape(TddFixture fx) async {
  const a1Description = 'the barcode scan completes and shows the result.';
  await fx.seedTestList([
    (
      id: 'A1',
      description: a1Description,
      traces: 'FR-001',
      state: 'PENDING',
      kind: 'acceptance',
    ),
    (
      id: 'U1',
      description: 'unit behavior backing A1',
      traces: 'FR-001',
      state: 'PENDING',
      kind: 'unit',
    ),
  ]);
  await fx.seedCertifiedRed(
    id: 'A1',
    description: a1Description,
    testContent: TddFixture.subjectDrivenTest('A1', a1Description),
  );
  // U1 gen'd: registry record + on-disk stub subject, no green evidence,
  // no wire anchor — the not-yet-driven state (an anchor for NO lane).
  await fx.registerBehavior(id: 'U1', description: 'unit behavior backing A1');
  await Directory(p.join(fx.root.path, 'lib')).create(recursive: true);
  await File(fx.subjectPathOf('U1')).writeAsString('int subject_u1() => 0;\n');
}

void main() {
  late TddFixture fx;
  final runner = CliRunner(exitOnCompletion: false);

  setUp(() async {
    fx = await TddFixture.create(featureName: '001-barcode-scan');
    await seedFreshProjectShape(fx);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('bug #1551 (1): the compose no-green-units precondition defers — '
      'it never grades generation-error', () {
    test('an acceptance make whose compose step reports no-green-units '
        'grades `unexpressible` (the deferral token) — not '
        '`generation-error`', () async {
      final stubBefore = await File(fx.subjectPathOf('A1')).readAsString();
      // The child transcript is the REAL compose failure (verbatim shape)
      // so the classification is exercised against production bytes.
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        stdoutByArgv: {
          'tdd compose': noGreenUnitsTranscript('A1', fx.featureName),
        },
        exitByArgv: {'tdd compose': 1},
      );

      final out = await runner.runCapturing(
        makeArgs(fx, id: 'A1', zfaBin: zfaBin),
      );

      // The deferral mapping (issue #1551 remedy 1): the unmet anchor
      // precondition is graded `unexpressible` — the token the run
      // driver's bug #625/#826 deferral arm consumes.
      expect(
        out,
        contains(
          'make: behavior=A1 outcome=unexpressible '
          'feature=${fx.featureName}',
        ),
        reason: out,
      );
      expect(
        out,
        isNot(contains('outcome=generation-error')),
        reason:
            'the unmet precondition is a deferral, not a generation '
            'defect — grading it generation-error is the #1551 deadlock '
            '(the run hard-stops at A1:make on every resume). Output:\n'
            '$out',
      );
      // The stop names the deferral and the issue (an actionable stop,
      // never a silent regrade).
      expect(out, contains('#1551'));
      expect(out, contains('phase 2'));
      // The make still exits non-zero — the same honesty class as every
      // other unexpressible site (exit 1, no green entry).
      expect(exitCode, isNot(0), reason: out);
      // The composition lane DID engage (the plan spawned the compose
      // step) — the pin is about the grading of its failure.
      final log = await fx.readFakeZfaLog();
      expect(
        log.where((l) => l.contains('tdd compose A1')),
        isNotEmpty,
        reason: 'the compose step must run before the deferral grading',
      );
      // The #1036 failed-make contract: the certified-red subject shape
      // survives the failed make byte-identically.
      expect(await File(fx.subjectPathOf('A1')).readAsString(), stubBefore);
      // No green evidence was appended (nothing went green).
      expect(
        await File(fx.cycleLogPath).readAsString(),
        isNot(contains('## Cycle: A1 (green)')),
      );
    });
  });

  group('bug #1551 (2): the grading feeds the EXISTING loop deferral arm', () {
    test('the make summary the run driver parses is exactly the bug #625 '
        'deferral token (unexpressible) on the summary line the '
        'StepRunner reads', () async {
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        stdoutByArgv: {
          'tdd compose': noGreenUnitsTranscript('A1', fx.featureName),
        },
        exitByArgv: {'tdd compose': 1},
      );

      final out = await runner.runCapturing(
        makeArgs(fx, id: 'A1', zfaBin: zfaBin),
      );

      // run_driver_core.dart's StepRunner parses the FINAL summary line's
      // `outcome=` kv pair (step_runner.dart, the make/refactor case).
      // `unexpressible` there is the deferral: `[run] A1 make -> deferred
      // (phase 2)` (run_command_test.dart bug 625/826 pins). The token
      // must therefore appear in the machine contract, on the final line.
      final summaryLine = out
          .split('\n')
          .map((l) => l.trimRight())
          .where((l) => l.startsWith('make: behavior='))
          .toList();
      expect(summaryLine, hasLength(1), reason: out);
      expect(
        summaryLine.single,
        'make: behavior=A1 outcome=unexpressible feature=${fx.featureName}',
        reason:
            'the run driver consumes exactly this kv contract — '
            'unexpressible here IS the phase-2 deferral',
      );
    });
  });

  group('bug #1551 (3): a compose against GREEN anchors still makes green', () {
    test('the same acceptance make composes and certifies green once the '
        'unit IS green (the #1512 surface is unbroken)', () async {
      // The units went green/wired (the phase-2 world): U1 carries green
      // cycle-log evidence and an on-disk subject — a composable anchor.
      await fx.seedGreenEvidence('U1');
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd compose': fx.overwriteSubjectCommands(
            'A1',
            TddFixture.subjectReturning('A1', 42),
          ),
        },
      );

      final out = await runner.runCapturing(
        makeArgs(fx, id: 'A1', zfaBin: zfaBin),
      );

      expect(exitCode, 0, reason: out);
      expect(
        out,
        contains('make: behavior=A1 outcome=green feature=${fx.featureName}'),
        reason: out,
      );
      final log = await fx.readFakeZfaLog();
      expect(log.first, contains('tdd compose A1'));
      expect(log.last, 'build');
      expect(
        await File(fx.cycleLogPath).readAsString(),
        contains('## Cycle: A1 (green)'),
      );
    });
  });

  group('bug #1551 (4): the direct compose surface is unchanged', () {
    test(
      'a direct `zfa tdd compose` on the fresh-project shape keeps its '
      'honest no-green-units stop (exit 1, summary line, no rewrite)',
      () async {
        final stubBefore = await File(fx.subjectPathOf('A1')).readAsString();

        final out = await runner.runCapturing(composeArgs(fx, id: 'A1'));

        expect(exitCode, isNot(0), reason: out);
        expect(
          out,
          contains(
            'compose: behavior=A1 outcome=no-green-units '
            'feature=${fx.featureName}',
          ),
          reason: out,
        );
        expect(out.toLowerCase(), contains('no green unit subjects'));
        expect(await File(fx.subjectPathOf('A1')).readAsString(), stubBefore);
      },
    );
  });

  group('bug #1551 (5): the remap NEGATIVE boundary — the deferral is '
      'exclusive to the made behavior\'s own no-green-units verdict', () {
    test('a compose failure whose summary names another outcome still grades '
        '`generation-error` (never `unexpressible`)', () async {
      // A REAL compose outcome other than no-green-units
      // (compose_command.dart's ComposeOutcome labels): the behavior is
      // not certified red. This is a genuine compose defect, NOT the
      // #1551 unmet precondition, so the narrow remap must leave it
      // graded `generation-error` — broadening
      // `_composeOutputReportsNoGreenUnits` to any summary line would
      // silently convert compose defects into phase-2 deferrals.
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        stdoutByArgv: {
          'tdd compose': [
            'compose: behavior=A1 outcome=not-certified-red '
                'feature=${fx.featureName}',
          ],
        },
        exitByArgv: {'tdd compose': 1},
      );

      final out = await runner.runCapturing(
        makeArgs(fx, id: 'A1', zfaBin: zfaBin),
      );

      expect(
        out,
        contains(
          'make: behavior=A1 outcome=generation-error '
          'feature=${fx.featureName}',
        ),
        reason: out,
      );
      expect(
        out,
        isNot(contains('outcome=unexpressible')),
        reason:
            'the phase-2 deferral is exclusive to the compose '
            'no-green-units precondition — any other compose failure '
            'keeps the honest generation-error stop. Output:\n$out',
      );
    });

    test('a `no-green-units` summary naming a DIFFERENT behavior still grades '
        '`generation-error`', () async {
      // The classification is bound to the behavior being made
      // (`record.behaviorId`): a no-green-units verdict belonging to
      // another behavior is not THIS behavior's precondition, so it
      // must not route the deferral.
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        stdoutByArgv: {
          'tdd compose': [
            'compose: behavior=A2 outcome=no-green-units '
                'feature=${fx.featureName}',
          ],
        },
        exitByArgv: {'tdd compose': 1},
      );

      final out = await runner.runCapturing(
        makeArgs(fx, id: 'A1', zfaBin: zfaBin),
      );

      expect(
        out,
        contains(
          'make: behavior=A1 outcome=generation-error '
          'feature=${fx.featureName}',
        ),
        reason: out,
      );
      expect(out, isNot(contains('outcome=unexpressible')), reason: out);
    });
  });
}
