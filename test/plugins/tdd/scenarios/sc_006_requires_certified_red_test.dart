@Tags(['slow'])
// Acceptance scenario sc_006: refuses to run without certified red
// (spec 047-tdd-make, US2.AC1 / US2.AC2 / US2.AC3).
//
// Three refusal paths:
//   A4: no red evidence → refused, verify-red remediation named
//   A5: unknown behavior id → refused, gen remediation, nothing generated
//   A6: already-green target test → drift reported, exit non-zero
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

  test('A4 — no red evidence refuses with not-certified-red BEFORE any '
      'pipeline invocation; the verify-red remediation is named', () async {
    // Register a behavior with artifacts but WITHOUT seeding red
    // evidence.
    await fx.registerBehavior(
      id: 'B-001',
      description: 'create entity User with email',
    );
    final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

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

    expect(exitCode, isNot(0));
    expect(out, contains('not-certified-red'));
    expect(out, contains('verify-red'));
    expect(
      out,
      contains(
        'make: behavior=B-001 outcome=not-certified-red '
        'feature=${fx.featureName}',
      ),
    );
    // Pipeline NEVER invoked (SC-002).
    final log = await fx.readFakeZfaLog();
    expect(log, isEmpty);
    // No cycle-log entry appended.
    final cycleLog = await File(fx.cycleLogPath).exists()
        ? await File(fx.cycleLogPath).readAsString()
        : '';
    expect(cycleLog, isNot(contains('## Cycle: B-001 (green)')));
  });

  test('A5 — unknown behavior id refuses naming the id, gen remediation, '
      'nothing generated', () async {
    final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'make',
      '--project',
      fx.root.path,
      '--zfa-bin',
      zfaBin,
      'B-404',
    ]);

    expect(exitCode, isNot(0));
    expect(out, contains('B-404'));
    expect(out, contains('unknown behavior id'));
    // Without --feature, an unknown id has no resolvable feature
    // context (mirrors verify-red_command.dart's behavior).
    expect(
      out,
      contains(
        'make: behavior=B-404 outcome=not-certified-red feature=unknown',
      ),
    );
    final log = await fx.readFakeZfaLog();
    expect(log, isEmpty);
  });

  test('A6 — already-green target test → drift reported, exit non-zero, '
      'no vacuous green', () async {
    // Seed certified-red but with a GREEN test (someone hand-
    // implemented the behavior — drift).
    await fx.seedCertifiedRed(
      id: 'B-001',
      description: 'create entity User with email',
      testContent: TddFixture.greenTest('create entity User with email'),
    );
    final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

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

    expect(exitCode, isNot(0));
    expect(out, contains('drift'));
    expect(
      out,
      contains('make: behavior=B-001 outcome=drift feature=${fx.featureName}'),
    );
    final log = await fx.readFakeZfaLog();
    expect(log, isEmpty);
  });
}
