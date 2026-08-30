@Tags(['slow'])
// Acceptance scenario sc_005: turns a certified-red behavior green
// through the real CLI (spec 047-tdd-make, US1.AC1 / US1.AC2 / US1.AC3).
//
// The scenario drives the actual `zfa tdd make` command end-to-end
// against a TddFixture project. The pipeline is a fake `zfa` script
// (the only way to keep the test deterministic and reproducible in
// CI); the fake's recorded invocations are the generation evidence
// the green entry records.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('A1/A2/A3 — certified-red behavior: implementation generated via '
      'pipeline, target test green, exit 0; green entry carries all '
      'contract fields including the recorded generation commands; the '
      'behavior\'s test file remains byte-identical', () async {
    // Seed the precondition: a certified-red behavior.
    const description = 'create entity User with email';
    await fx.seedCertifiedRed(
      id: 'B-001',
      description: description,
      testContent: TddFixture.subjectDrivenTest('B-001', description),
    );
    final testBytesBefore = await File(fx.testPathOf('B-001')).readAsBytes();
    final zfaBin = await fx.writeFakeZfaBin(
      logPath: fx.fakeZfaLogPath,
      sideEffectByArgv: {
        'entity create': fx.overwriteSubjectCommands(
          'B-001',
          TddFixture.subjectReturning('B-001', 42),
        ),
      },
    );

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'make',
      '--project',
      fx.root.path,
      '--zfa-bin',
      zfaBin,
      'B-001',
    ]);

    // US1.AC1: exit 0, target test green, machine-readable summary.
    expect(exitCode, 0, reason: 'out:\n$out');
    expect(
      out,
      contains('make: behavior=B-001 outcome=green feature=${fx.featureName}'),
    );

    // US1.AC2: green entry carries all 8 contract fields including
    // the recorded generation commands.
    final log = await File(fx.cycleLogPath).readAsString();
    expect(log, contains('## Cycle: B-001 (green)'));
    expect(log, contains('- behavior: B-001'));
    expect(log, contains('- kind: green'));
    expect(log, contains('- criterion:'));
    expect(log, contains('- test:'));
    expect(log, contains('- command:'));
    expect(log, contains('- exit: 0'));
    expect(log, contains('- at:'));
    expect(log, contains('- generation:'));
    expect(log, contains('zfa entity create'));
    expect(log, contains('purpose: create entity'));
    expect(log, contains('- suite: baseline='));
    expect(log, contains('guard='));

    // US1.AC3: the recorded pipeline invocations, replayed on the
    // pre-run state, reproduce the implementation (SC-001) —
    // verifiable from the cycle log alone.
    final calls = await fx.readFakeZfaLog();
    expect(calls, hasLength(2));
    expect(calls.first, contains('entity create'));
    expect(calls.last, contains('build'));
    expect(await File(fx.testPathOf('B-001')).readAsBytes(), testBytesBefore);
  });
}
