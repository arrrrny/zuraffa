@Tags(['slow'])
// Acceptance scenario SC-010: red-suite and unrunnable-suite refusal
// (spec 048-tdd-refactor, T008; A2, A3).
//
// Drives the real CLI entry point against a TddFixture project whose suite
// is red or whose runner is broken, asserting the preflight gate refuses
// before any file change.
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

  test('SC-010.A2: red suite → outcome=not-green, failing test named, '
      'zero files modified', () async {
    await fx.seedRedSuite(testDescription: 'red baseline');
    final checksumsBefore = fx.checksumTestAndLib();

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'refactor',
      '--project',
      fx.root.path,
    ]);

    expect(out, contains('outcome=not-green'));
    expect(out, contains('zfa tdd make'));
    expect(out.toLowerCase(), contains('red baseline'));
    expect(exitCode, isNot(0));
    // Zero files modified across the entire project.
    expect(fx.checksumTestAndLib(), equals(checksumsBefore));
  });

  test('SC-010.A3: unrunnable suite → outcome=runner-error, zero files '
      'modified', () async {
    final fxBroken = await TddFixture.create(
      suiteTemplate: 'definitely_not_a_real_binary_xyz_suite',
    );
    try {
      await fxBroken.seedGreenSuite();
      final checksumsBefore = fxBroken.checksumTestAndLib();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'refactor',
        '--project',
        fxBroken.root.path,
      ]);

      expect(out, contains('outcome=runner-error'));
      expect(exitCode, isNot(0));
      expect(fxBroken.checksumTestAndLib(), equals(checksumsBefore));
    } finally {
      fxBroken.dispose();
      exitCode = 0;
    }
  });

  test(
    'SC-010.FR-002: no --skip-preflight flag exists (flag is rejected)',
    () async {
      await fx.seedGreenSuite();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'refactor',
        '--project',
        fx.root.path,
        '--skip-preflight',
      ]);
      expect(out.toLowerCase(), contains('could not find an option'));
      expect(out.toLowerCase(), contains('skip-preflight'));
      expect(out, isNot(contains('refactor: feature=')));
    },
  );
}
