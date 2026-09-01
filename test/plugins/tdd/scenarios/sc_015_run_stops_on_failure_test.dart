@Tags(['slow'])
// SC-015 acceptance tests (spec 049-tdd-run, US3 / T017): the driver stops
// honestly on failure — make unexpressible leaves the behavior RED and
// DEFERS to phase 2 instead of blocking the feature (A7, bug #657), the
// report names behavior, step, outcome class, and the resume command (A8),
// and a done claim without green evidence is never honored (A9).
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '090-run-stop';

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

  Future<void> seedThreeBehaviors() => fx.seedTestList([
    (
      id: 'B-001',
      description: 'first behavior',
      traces: 'FR-007',
      state: 'PENDING',
      kind: 'unit',
    ),
    (
      id: 'B-002',
      description: 'second behavior',
      traces: 'FR-007',
      state: 'PENDING',
      kind: 'unit',
    ),
    (
      id: 'B-003',
      description: 'third behavior',
      traces: 'FR-007',
      state: 'PENDING',
      kind: 'unit',
    ),
  ]);

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.writeFakeZfa();
    await seedThreeBehaviors();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test(
    'A7: make unexpressible at B-002 defers (bug #657) — B-003 still runs, '
    'the honest stop lands at the phase-2 re-attempt of B-002:make',
    () async {
      await fx.setStepOutcome('make', 'B-002', 'unexpressible');

      final out = await drive();

      expect(exitCode, isNot(0), reason: out);
      expect(
        out,
        contains(
          'run: feature=$feature result=stopped pending=0 red=1 green=1 '
          'done=1 '
          'stopped_at=B-002:make',
        ),
        reason: out,
      );
      // Residual state: B-001 done, B-002 still red, B-003 green (its
      // refactor deferred while B-002 sat RED).
      final state =
          jsonDecode(await File(fx.runStatePath).readAsString())
              as Map<String, dynamic>;
      expect(state['behavior_states'] as Map<String, dynamic>, {
        'B-001': 'done',
        'B-002': 'red',
        'B-003': 'green',
      });
      // B-003 ran its gen/verify-red/make after B-002's deferral, and the
      // run ended on the phase-2 make re-attempt of B-002.
      final invocations = fx.stepInvocations();
      expect(
        invocations,
        containsAllInOrder([
          'make B-002',
          'gen B-003',
          'verify-red B-003',
          'make B-003',
          'make B-002',
        ]),
      );
      expect(
        invocations.where((l) => l == 'refactor B-003'),
        isEmpty,
        reason: 'refactor must defer while B-002 sits RED',
      );
      // B-002 has red evidence but no green evidence.
      final log = await File(fx.cycleLogPath).readAsString();
      expect(RegExp('## Cycle: B-002 \\(green\\)').allMatches(log).length, 0);
    },
  );

  test(
    'A8: the failure report names behavior, step, outcome, resume command',
    () async {
      await fx.setStepOutcome('verify-red', 'B-001', 'compile-error');

      final out = await drive();

      expect(exitCode, isNot(0), reason: out);
      expect(
        out,
        contains(
          'run: feature=$feature result=stopped pending=3 red=0 green=0 done=0 '
          'stopped_at=B-001:verify-red',
        ),
        reason: out,
      );
      // The report names the behavior, the failing step, and the outcome class.
      expect(out, contains('behavior=B-001'));
      expect(out, contains('step=verify-red'));
      expect(out, contains('outcome=compile-error'));
      // Resume instructions name the command to re-run.
      expect(out, contains('zfa tdd run $feature'));
    },
  );

  test(
    'A9: red without green evidence is never DONE, whatever the state says',
    () async {
      // The state file claims B-001 done, but the cycle log holds only its
      // red entry — evidence beats state, so B-001 is re-driven from make.
      // B-001 keeps its gen artifacts registered so the #720 artifact
      // check honors the demoted red claim's make re-entry.
      await fx.registerBehavior(id: 'B-001', description: 'first behavior');
      await fx.seedRedEvidence('B-001');
      await fx.seedRunState(
        states: {'B-001': 'done', 'B-002': 'pending', 'B-003': 'pending'},
      );

      final out = await drive();

      expect(exitCode, 0, reason: out);
      expect(
        out,
        contains(
          'run: feature=$feature result=complete pending=0 red=0 green=0 done=3',
        ),
        reason: out,
      );
      // B-001 was re-driven from make (not gen): the demotion honored the
      // evidence-backed state (red), and the re-drive completed it.
      expect(fx.stepInvocations().first, 'make B-001');
      final log = await File(fx.cycleLogPath).readAsString();
      expect(RegExp('## Cycle: B-001 \\(green\\)').allMatches(log).length, 1);
      final state =
          jsonDecode(await File(fx.runStatePath).readAsString())
              as Map<String, dynamic>;
      expect(
        (state['behavior_states'] as Map<String, dynamic>)['B-001'],
        'done',
      );
    },
  );
}
