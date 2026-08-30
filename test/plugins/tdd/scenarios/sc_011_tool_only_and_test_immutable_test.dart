@Tags(['slow'])
// Acceptance scenario SC-011: tool-only changes + test immutability
// (spec 048-tdd-refactor, T013; A4, A5, A6).
//
// Drives the real CLI against a fixture with a malformed lib/ file; asserts
// every changed lib/ path is attributable to a recorded tool action and
// the test/ tree is byte-identical before/after.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
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
    'SC-011.A5: test/ is byte-identical after the run (checksum-verified)',
    () async {
      await fx.seedMalformedLib();
      final testBefore = _checksumTree(fx.root.path, 'test');

      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(['tdd', 'refactor', '--project', fx.root.path]);

      final testAfter = _checksumTree(fx.root.path, 'test');
      expect(testAfter, equals(testBefore));
    },
  );

  test(
    'SC-011.A6: every changed lib/ path appears in a recorded action',
    () async {
      await fx.seedMalformedLib();
      final libBefore = _checksumTree(fx.root.path, 'lib');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'refactor',
        '--project',
        fx.root.path,
      ]);

      final libAfter = _checksumTree(fx.root.path, 'lib');
      final changedPaths = <String>{};
      for (final k in {...libBefore.keys, ...libAfter.keys}) {
        if (libBefore[k] != libAfter[k]) {
          changedPaths.add(k);
        }
      }

      if (changedPaths.isNotEmpty) {
        // The cycle-log entry must list every changed path under actions.
        expect(out, contains('outcome=refactored'));
        final log = await File(fx.cycleLogPath).readAsString();
        expect(log, contains('actions:'));
        for (final path in changedPaths) {
          expect(
            log,
            contains(path),
            reason:
                'lib/ change at $path not attributed to any recorded action',
          );
        }
      } else {
        // Nothing changed → clean no-op.
        expect(out, contains('outcome=clean'));
      }
    },
  );

  test('SC-011.A4: each recorded action lists its exact command', () async {
    await fx.seedMalformedLib();
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'refactor',
      '--project',
      fx.root.path,
    ]);

    if (out.contains('outcome=refactored')) {
      final log = await File(fx.cycleLogPath).readAsString();
      // Each action block in the log records its command verbatim.
      expect(
        log,
        contains(
          RegExp(
            r'command: `(zfa build|dart format lib/|dart fix --apply lib/)`',
          ),
        ),
      );
    }
  });
}

Map<String, String> _checksumTree(String projectRoot, String treeName) {
  final sums = <String, String>{};
  final dir = Directory(p.join(projectRoot, treeName));
  if (!dir.existsSync()) return sums;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      sums[p.relative(entity.path, from: projectRoot)] = entity
          .readAsStringSync();
    }
  }
  return sums;
}
