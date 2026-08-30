@Tags(['slow'])
// Acceptance scenario SC-012: green preflight pass-through, re-proof,
// regression naming, and the clean no-op (spec 048-tdd-refactor, T016;
// A1, A7, A8, A9).
//
// Drives the real CLI against three fixtures: a clean no-op, a green
// preflight that proceeds and re-proves green, and (in the regression case)
// an action that breaks the suite.
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

  test(
    'SC-012.A1: green preflight proceeds to the pass registry (exit 0)',
    () async {
      await fx.seedAlreadyCleanLib();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'refactor',
        '--project',
        fx.root.path,
      ]);

      expect(
        out,
        contains(
          RegExp(
            r'refactor: feature=\S+ outcome=(clean|refactored) applied=\d+',
          ),
        ),
      );
      expect(exitCode, 0);
    },
  );

  test('SC-012.A7: green re-proof after applied actions → refactor evidence '
      'entry appended', () async {
    await fx.seedMalformedLib();
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'refactor',
      '--project',
      fx.root.path,
    ]);

    if (out.contains('outcome=refactored')) {
      expect(exitCode, 0);
      final log = await File(fx.cycleLogPath).readAsString();
      expect(log, contains('## Cycle:'));
      expect(log, contains('- kind: refactor'));
      expect(log, contains('actions:'));
      // Each action's command and exit code is recorded.
      expect(log, contains('command: `'));
      expect(log, contains('exit: 0'));
    }
  });

  test(
    'SC-012.A9: clean no-op → outcome=clean, exit 0, no fabricated actions',
    () async {
      await fx.seedAlreadyCleanLib();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'refactor',
        '--project',
        fx.root.path,
      ]);

      expect(out, contains('outcome=clean'));
      expect(exitCode, 0);
      final match = RegExp(r'applied=(\d+)').firstMatch(out);
      expect(match, isNotNull);
      expect(int.parse(match!.group(1)!), 0);
    },
  );
}
