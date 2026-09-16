// Issue #1652 — driver-level contract: a phase-1 refactor reached in the
// SAME drive whose make just certified the behavior green is DEFERRED into
// the existing phase-2b batch pass, instead of spawning between makes.
//
// Why: forward progress changes `lib/` on every make, so the #1624/#1588
// pass-batch ledger can never inherit between consecutive behaviors and
// the #1652 make-post-state record (PR #1662) is the only gate left —
// best-effort derived data whose every mismatch dimension costs a FULL
// pipeline per behavior. Deferring makes the economics structural: all
// makes complete first, the tree is byte-stable across the batch, and the
// full-suite gate runs at most once per lane per run.
//
// Contracts pinned here (the bug-1588 driver-level harness shape — the
// step commands are the fixture's scripted fake zfa spawned as real
// sub-processes, fast tier: no profile, no real suite spawns):
//   A1  — a forward run defers every same-drive-make refactor to the
//         phase-2b batch pass (zero phase-1 refactor spawns, deferral
//         lines, DONE through the batch); includes the #694 skip
//         transition variant (A1b).
//   A2  — batch-boundary scheduling: all makes precede all refactors,
//         every refactor spawn carries --pass-batch, result=complete.
//   A3  — the resume re-entry window (state green, no make in drive) is
//         unchanged: the refactor still spawns in phase 1 exactly once,
//         carrying --pass-batch (the bug-1624 contract).
//   A4  — a parked blocked contract composes: the unit defers in phase 1,
//         its phase-2b spawn carries --exempt-behaviors, result=blocked.
//   A5  — a later make failure stops the run with earlier refactors
//         deferred: no batch pass, no fabricated refactor evidence.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  const feature = '092-defer-phase1-refactor';
  late TddFixture fx;

  Future<String> drive() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'run',
      feature,
      '--project',
      fx.root.path,
      '--zfa-bin',
      fx.fakeZfaBin,
    ]);
  }

  Future<List<String>> argvLog() async {
    final file = File(fx.fakeZfaArgvLogPath);
    if (!await file.exists()) return const [];
    final raw = await file.readAsString();
    return raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>> behaviorStates() async =>
      (jsonDecode(await File(fx.runStatePath).readAsString())
              as Map<String, dynamic>)['behavior_states']
          as Map<String, dynamic>;

  setUp(() async {
    // Fast tier: no profile, so the #741 baseline never spawns a real
    // suite (the fake zfa scripts every step).
    fx = await TddFixture.create(featureName: feature, writeProfile: false);
    await fx.writeFakeZfa();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('A1 — forward-run deferral', () {
    test('a forward run defers every same-drive-make refactor to the '
        'phase-2b batch pass — zero phase-1 refactor spawns, DONE through '
        'the batch', () async {
      await fx.seedTestList([
        (
          id: 'B-001',
          description: 'first behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'B-002',
          description: 'second behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);

      final out = await drive();

      expect(exitCode, 0, reason: out);
      // THE scheduling assertion: every refactor spawn happens AFTER the
      // last make — nothing spawns between makes in phase 1.
      final steps = fx.stepInvocations();
      final lastMake = steps.lastIndexWhere((l) => l.startsWith('make '));
      final firstRefactor = steps.indexWhere((l) => l.startsWith('refactor '));
      expect(lastMake, isNot(-1), reason: steps.join('\n'));
      expect(firstRefactor, isNot(-1), reason: out);
      expect(
        firstRefactor,
        greaterThan(lastMake),
        reason:
            'no refactor may spawn before the last make '
            '(step log: ${steps.join(', ')})',
      );
      // The deferral is the existing machinery, named per behavior.
      expect(out, contains('[run] B-001 refactor -> deferred (phase 2)'));
      expect(out, contains('[run] B-002 refactor -> deferred (phase 2)'));
      // Exactly ONE refactor spawn per behavior — the batch's.
      final argv = await argvLog();
      expect(
        argv.where((l) => l.startsWith('tdd refactor B-001')),
        hasLength(1),
        reason: argv.join('\n'),
      );
      expect(
        argv.where((l) => l.startsWith('tdd refactor B-002')),
        hasLength(1),
        reason: argv.join('\n'),
      );
      // Both behaviors land DONE through the batch pass (FR-005).
      final states = await behaviorStates();
      expect(states['B-001'], 'done');
      expect(states['B-002'], 'done');
    });

    test('A1b: the #694 skip transition (make outcome=skipped, exit 0) '
        'defers the following refactor exactly like a green make', () async {
      await fx.seedTestList([
        (
          id: 'B-001',
          description: 'already-green behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.setStepOutcome('make', 'B-001', 'skip');

      final out = await drive();

      expect(exitCode, 0, reason: out);
      final steps = fx.stepInvocations();
      final lastMake = steps.lastIndexWhere((l) => l.startsWith('make '));
      final firstRefactor = steps.indexWhere((l) => l.startsWith('refactor '));
      expect(firstRefactor, isNot(-1), reason: out);
      expect(firstRefactor, greaterThan(lastMake), reason: steps.join('\n'));
      expect(out, contains('[run] B-001 refactor -> deferred (phase 2)'));
      final states = await behaviorStates();
      expect(states['B-001'], 'done');
    });
  });

  group('A2 — batch-boundary scheduling and argv contract', () {
    test('all makes precede all refactors and every refactor spawn carries '
        '--pass-batch; the run completes', () async {
      await fx.seedTestList([
        (
          id: 'B-001',
          description: 'first behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'B-002',
          description: 'second behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);

      final out = await drive();

      expect(exitCode, 0, reason: out);
      expect(out, contains('result=complete'), reason: out);
      expect(out, contains('done=2'), reason: out);
      final argv = await argvLog();
      final firstRefactor = argv.indexWhere(
        (l) => l.startsWith('tdd refactor '),
      );
      final lastNonRefactor = argv.lastIndexWhere(
        (l) => !l.startsWith('tdd refactor '),
      );
      expect(firstRefactor, isNot(-1), reason: argv.join('\n'));
      expect(
        firstRefactor,
        greaterThan(lastNonRefactor),
        reason:
            'every non-refactor spawn (gen/verify-red/make) must precede '
            'every refactor spawn (argv log: ${argv.join(' | ')})',
      );
      // The #1588/#1624 argv contract: every refactor spawn carries the
      // ledger opt-in.
      final refactorArgv = argv
          .where((l) => l.startsWith('tdd refactor '))
          .toList();
      expect(refactorArgv, hasLength(2), reason: argv.join('\n'));
      for (final line in refactorArgv) {
        expect(line, contains('--pass-batch'), reason: line);
      }
    });
  });

  group('A3 — the resume re-entry window is unchanged', () {
    test('a behavior re-entering phase 1 directly at refactor still spawns '
        'in phase 1 exactly once, carrying --pass-batch', () async {
      await fx.seedTestList([
        (
          id: 'A1',
          description: 'green unit behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.registerBehavior(
        id: 'A1',
        description: 'green unit behavior',
        writeTestFile: false,
      );
      await fx.seedRedEvidence('A1');
      await fx.seedGreenEvidence('A1');
      await fx.seedRunState(states: {'A1': 'green'});

      final out = await drive();

      expect(exitCode, 0, reason: out);
      // No make in this drive — the refactor is NOT deferred: this IS the
      // phase-1 spawn (the bug-1624 contract, preserved verbatim).
      final refactorSpawns = (await argvLog())
          .where((l) => l.startsWith('tdd refactor A1'))
          .toList();
      expect(refactorSpawns, hasLength(1), reason: out);
      expect(
        refactorSpawns.single,
        contains('--pass-batch'),
        reason: refactorSpawns.single,
      );
      expect(
        refactorSpawns.single,
        isNot(contains('--exempt-behaviors')),
        reason: refactorSpawns.single,
      );
      expect(out, isNot(contains('[run] A1 refactor -> deferred (phase 2)')));
      final states = await behaviorStates();
      expect(states['A1'], 'done');
    });
  });

  group('A4 — parked blocked contract composition', () {
    test(
      'the unit defers in phase 1 and its phase-2b spawn carries '
      '--exempt-behaviors; the run reports result=blocked blocked=1',
      () async {
        await fx.seedTestList([
          (
            id: 'U1',
            description: 'made unit behavior',
            traces: 'FR-001',
            state: 'PENDING',
            kind: 'unit',
          ),
          (
            id: 'contract:C1',
            description:
                'User.validateEmail(String email) -> bool (entity method '
                'contract)',
            traces: 'User.validateEmail',
            state: 'PENDING',
            kind: 'contract',
          ),
        ]);
        // The parked contract: this run's verify-red reports the blocked
        // verdict (#1007) — the behavior parks at BLOCKED and make/refactor
        // never spawn for it.
        await fx.setStepOutcome('verify-red', 'contract:C1', 'blocked');

        final out = await drive();

        // The blocked behavior parks the run honestly (#1544 semantics):
        // exit 1, result=blocked — while U1 still reaches done.
        expect(exitCode, 1, reason: out);
        expect(out, contains('result=blocked'), reason: out);
        expect(out, contains('blocked=1'), reason: out);
        // U1's refactor deferred in phase 1 (no spawn between its make and
        // the batch pass).
        expect(out, contains('[run] U1 refactor -> deferred (phase 2)'));
        final refactorSpawns = (await argvLog())
            .where((l) => l.startsWith('tdd refactor U1'))
            .toList();
        expect(refactorSpawns, hasLength(1), reason: out);
        expect(
          refactorSpawns.single,
          contains('--pass-batch'),
          reason: refactorSpawns.single,
        );
        // The lane's parked BLOCKED id rides the batch spawn (#1588).
        expect(
          refactorSpawns.single,
          contains('--exempt-behaviors contract:C1'),
          reason: refactorSpawns.single,
        );
        final states = await behaviorStates();
        expect(states['U1'], 'done');
        expect(states['contract:C1'], 'blocked');
      },
    );
  });

  group('A5 — honest stop with deferred refactors', () {
    test(
      'a later make failure stops the run — earlier behaviors stay green '
      'with deferred refactors, no batch pass, no fabricated evidence',
      () async {
        await fx.seedTestList([
          (
            id: 'B-001',
            description: 'first behavior',
            traces: 'FR-001',
            state: 'PENDING',
            kind: 'unit',
          ),
          (
            id: 'B-002',
            description: 'second behavior',
            traces: 'FR-001',
            state: 'PENDING',
            kind: 'unit',
          ),
        ]);
        await fx.setStepOutcome('make', 'B-002', 'not-certified-red');

        final out = await drive();

        // Honest stop at the failing make.
        expect(exitCode, 1, reason: out);
        expect(out, contains('stopped_at=B-002:make'), reason: out);
        // B-001's refactor never spawned — deferred, and the run stopped
        // before any phase-2b pass.
        final refactorSpawns = (await argvLog())
            .where((l) => l.startsWith('tdd refactor '))
            .toList();
        expect(refactorSpawns, isEmpty, reason: out);
        expect(out, contains('[run] B-001 refactor -> deferred (phase 2)'));
        // B-001 keeps its green state (never a fake DONE, FR-008).
        final states = await behaviorStates();
        expect(states['B-001'], 'green');
        expect(states['B-002'], isNot('done'));
        // No refactor evidence was fabricated for B-001.
        final log = await File(fx.cycleLogPath).readAsString();
        expect(log, isNot(contains('kind: refactor')), reason: log);
      },
    );
  });
}
