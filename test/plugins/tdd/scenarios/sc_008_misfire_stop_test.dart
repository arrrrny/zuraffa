@Tags(['slow'])
// Acceptance scenario sc_008: misfire-stop on unexpressible behaviors
// (spec 047-tdd-make, US4.AC1 / US4.AC2 / US4.AC3).
//
// Three misfire cases:
//   A10: pipeline-inexpressible behavior → exit non-zero naming the
//        unmet capability, no evidence.
//   A11: failing generation step → exit non-zero naming the step, no
//        test-suite run against broken code.
//   A12: any misfire leaves the behavior's test file and the cycle
//        log unchanged.
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

  test('A10 — pipeline-inexpressible behavior → exit non-zero naming the '
      'unmet capability, no evidence', () async {
    await fx.seedCertifiedRed(
      id: 'B-042',
      description: 'parse bespoke DSL syntax with no generator surface',
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
      'B-042',
    ]);

    expect(exitCode, isNot(0));
    expect(out, contains('unexpressible'));
    // SC-005: the report names the unmet capability in behavior terms.
    expect(out, contains('B-042'));
    expect(out.toLowerCase(), contains('pipeline'));
    expect(out.toLowerCase(), contains('cannot express'));
    expect(
      out,
      contains(
        'make: behavior=B-042 outcome=unexpressible '
        'feature=${fx.featureName}',
      ),
    );
    // Pipeline NEVER invoked.
    final log = await fx.readFakeZfaLog();
    expect(log, isEmpty);
    // No green evidence written.
    final cycleLog = await File(fx.cycleLogPath).readAsString();
    expect(cycleLog, isNot(contains('## Cycle: B-042 (green)')));
  });

  test('A11 — failing generation step → exit non-zero naming the step, no '
      'test-suite run against broken code', () async {
    await fx.seedCertifiedRed(
      id: 'B-001',
      description: 'create entity User with email',
    );
    // The fake zfa exits 1 on `entity create` → generation-error.
    final zfaBin = await fx.writeFakeZfaBin(
      logPath: fx.fakeZfaLogPath,
      exitByArgv: {'entity create': 1},
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

    expect(exitCode, isNot(0));
    expect(out, contains('generation-error'));
    // The failing step is named.
    expect(out, contains('entity create'));
    expect(
      out,
      contains(
        'make: behavior=B-001 outcome=generation-error '
        'feature=${fx.featureName}',
      ),
    );
    // The test suite was NEVER run against the broken code: only one
    // fake-zfa invocation (entity create failed; build never ran).
    final log = await fx.readFakeZfaLog();
    expect(log, hasLength(1));
    expect(log.first, contains('entity create'));
  });

  test('A12 — any misfire leaves the behavior\'s test file and the cycle '
      'log unchanged', () async {
    await fx.seedCertifiedRed(
      id: 'B-042',
      description: 'parse bespoke DSL syntax with no generator surface',
    );
    final beforeChecksums = fx.checksumTestAndLib();
    final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

    final runner = CliRunner(exitOnCompletion: false);
    await runner.runCapturing([
      'tdd',
      'make',
      '--project',
      fx.root.path,
      '--zfa-bin',
      zfaBin,
      'B-042',
    ]);

    expect(exitCode, isNot(0));
    // SC-004: test file byte-identical (no pipeline ran).
    expect(fx.checksumTestAndLib(), equals(beforeChecksums));
    // No green evidence written.
    final cycleLog = await File(fx.cycleLogPath).readAsString();
    expect(cycleLog, isNot(contains('## Cycle: B-042 (green)')));
  });
}
