@Tags(['slow'])
// SC-015 acceptance tests (spec 049-tdd-run, US3 / T017): the driver stops
// honestly on failure — make unexpressible leaves the behavior RED and
// never starts later behaviors (A7), the report names behavior, step,
// outcome class, and the resume command (A8), and a done claim without
// green evidence is never honored (A9).
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
    'A7: make unexpressible at B-002 stops, B-002 stays RED, B-003 never started',
    () async {
      await fx.setStepOutcome('make', 'B-002', 'unexpressible');

      final out = await drive();

      expect(exitCode, isNot(0), reason: out);
      expect(
        out,
        contains(
          'run: feature=$feature result=stopped pending=1 red=1 green=0 done=1 '
          'stopped_at=B-002:make',
        ),
        reason: out,
      );
      // Residual state: B-001 done, B-002 still red, B-003 untouched.
      final state =
          jsonDecode(await File(fx.runStatePath).readAsString())
              as Map<String, dynamic>;
      expect(state['behavior_states'] as Map<String, dynamic>, {
        'B-001': 'done',
        'B-002': 'red',
        'B-003': 'pending',
      });
      // No later behavior started: nothing for B-003 in the invocation log.
      expect(fx.stepInvocations().last, 'make B-002');
      expect(fx.stepInvocations().where((l) => l.contains('B-003')), isEmpty);
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
