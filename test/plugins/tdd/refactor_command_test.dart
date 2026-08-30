@Tags(['slow'])
// Tests for the RefactorCommand (spec 048-tdd-refactor, T007, T012, T015,
// T018; behaviors U13-U22 + A1, A4-A6, A7-A9, A10-A11).
//
// Drives the public CLI surface (`zfa tdd refactor`) against real temp
// fixture projects; the suite preflight + re-proof execute REAL `dart test`
// subprocesses inside the fixture. Passes run via an injectable executor
// (overridden through a hidden flag) so the pass-registry behavior can be
// tested without real `zfa build` / `dart format` / `dart fix` subprocesses.
//
// The fixture root is passed explicitly via `--project`, so this suite never
// mutates the process-global Directory.current.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

/// Build the CLI args for `zfa tdd refactor`, pinning the project root so
/// the command resolves specs/test/.specify under [fx] without depending on
/// Directory.current.
List<String> refactorArgs(TddFixture fx, {String? feature}) => [
  'tdd',
  'refactor',
  '--project',
  fx.root.path,
  if (feature != null) ...['--feature', feature],
];

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('US1 — Green-suite preflight gate (T007 / U13-U15, A1-A3)', () {
    test('U13/A1: green preflight proceeds to the pass registry '
        '(outcome=clean or refactored, exit 0)', () async {
      await fx.seedAlreadyCleanLib();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(refactorArgs(fx));

      // Summary line contract (FR-009).
      expect(
        out,
        contains(
          RegExp(
            r'refactor: feature=\S+ outcome=(clean|refactored) applied=\d+',
          ),
        ),
      );
      expect(exitCode, 0);
    });

    test('U14/A2: red suite refuses — outcome=not-green, failing test named, '
        'zero files modified', () async {
      await fx.seedRedSuite();
      final checksumsBefore = fx.checksumTestAndLib();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(refactorArgs(fx));

      expect(out, contains('outcome=not-green'));
      expect(out, contains('zfa tdd make'));
      // The failing test must be named in the output.
      expect(out.toLowerCase(), contains('red baseline'));
      expect(exitCode, isNot(0));
      // Zero files modified.
      expect(fx.checksumTestAndLib(), equals(checksumsBefore));
    });

    test('U15/A3: unrunnable suite (broken runner) classifies runner-error, '
        'zero files modified', () async {
      // Use a suite template that points at a non-existent binary.
      final fxBroken = await TddFixture.create(
        suiteTemplate: 'definitely_not_a_real_binary_xyz_suite',
      );
      try {
        await fxBroken.seedGreenSuite();
        final checksumsBefore = fxBroken.checksumTestAndLib();

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(refactorArgs(fxBroken));

        expect(out, contains('outcome=runner-error'));
        expect(exitCode, isNot(0));
        expect(fxBroken.checksumTestAndLib(), equals(checksumsBefore));
      } finally {
        fxBroken.dispose();
        exitCode = 0;
      }
    });

    test('U22: missing tdd-profile misfire-stops before any pass '
        '(outcome=runner-error)', () async {
      await fx.seedGreenSuite();
      File('${fx.root.path}/.specify/memory/tdd-profile.md').deleteSync();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(refactorArgs(fx));

      expect(out.toLowerCase(), contains('tdd-profile.md'));
      expect(out, contains('outcome=runner-error'));
      expect(exitCode, isNot(0));
    });

    test(
      'FR-002: there is no --skip-preflight option (flag is rejected)',
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
        // args rejects unknown flags with a usage error message.
        expect(out.toLowerCase(), contains('could not find an option'));
        expect(out.toLowerCase(), contains('skip-preflight'));
        // No summary line is emitted on usage errors.
        expect(out, isNot(contains('refactor: feature=')));
      },
    );
  }, timeout: const Timeout(Duration(minutes: 8)));

  group('US2 — Tool-driven refactors only (T012 / U16-U17, A4-A6)', () {
    test('A4: malformed lib is normalized by recorded tool actions, each with '
        'its command', () async {
      await fx.seedMalformedLib();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(refactorArgs(fx));

      // The suite was green before AND after, so outcome is clean or
      // refactored (likely refactored because format normalized the file).
      expect(
        out,
        contains(
          RegExp(
            r'refactor: feature=\S+ outcome=(clean|refactored) applied=\d+',
          ),
        ),
      );
      expect(exitCode, 0);

      // When actions were applied, each is recorded with its command.
      if (out.contains('outcome=refactored')) {
        // The actions block in the cycle-log lists every action.
        final log = await File(fx.cycleLogPath).readAsString();
        expect(log, contains('actions:'));
        // Each action block names its command.
        expect(
          log,
          contains(
            RegExp(
              r'command: `(dart run bin/zfa\.dart build|dart format lib/|dart fix --apply lib/)`',
            ),
          ),
        );
      }
    });

    test('A5: every file under test/ is byte-identical after the run '
        '(checksum-verified)', () async {
      await fx.seedMalformedLib();
      // Compute checksums of test/ only.
      final testBefore = _checksumTree(fx.root.path, 'test');

      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(refactorArgs(fx));

      final testAfter = _checksumTree(fx.root.path, 'test');
      expect(testAfter, equals(testBefore));
    });

    test(
      'A6: every changed lib/ file is attributable to a recorded action',
      () async {
        await fx.seedMalformedLib();
        final libBefore = _checksumTree(fx.root.path, 'lib');

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(refactorArgs(fx));

        final libAfter = _checksumTree(fx.root.path, 'lib');
        if (libAfter.length != libBefore.length ||
            !libAfter.keys.every((k) => libBefore[k] == libAfter[k])) {
          // lib/ changed — every changed path must appear in some action's
          // filesChanged.
          final changedPaths = <String>{};
          for (final k in {...libBefore.keys, ...libAfter.keys}) {
            if (libBefore[k] != libAfter[k]) {
              changedPaths.add(k);
            }
          }
          final log = await File(fx.cycleLogPath).readAsString();
          for (final path in changedPaths) {
            expect(
              log,
              contains(path),
              reason: 'lib/ change at $path not attributed to any action',
            );
          }
        }
        // Outcome summary still emitted.
        expect(
          out,
          contains(RegExp(r'refactor: feature=\S+ outcome=\S+ applied=\d+')),
        );
      },
    );
  }, timeout: const Timeout(Duration(minutes: 8)));

  group(
    'US3 — Post-refactor re-proof and evidence (T015 / U18-U20, A7-A9)',
    () {
      test('A7: green re-proof after applied actions → exit 0 and a refactor '
          'evidence entry listing every action + command', () async {
        await fx.seedMalformedLib();
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(refactorArgs(fx));

        if (out.contains('outcome=refactored')) {
          expect(exitCode, 0);
          final log = await File(fx.cycleLogPath).readAsString();
          expect(log, contains('## Cycle:'));
          expect(log, contains('- kind: refactor'));
          expect(log, contains('actions:'));
        }
      });

      test(
        'A9: nothing to change → clean no-op, exit 0, no fabricated actions',
        () async {
          await fx.seedAlreadyCleanLib();
          final runner = CliRunner(exitOnCompletion: false);
          final out = await runner.runCapturing(refactorArgs(fx));

          expect(out, contains('outcome=clean'));
          expect(exitCode, 0);
          // No fabricated actions: applied count is 0.
          final match = RegExp(r'applied=(\d+)').firstMatch(out);
          expect(match, isNotNull);
          expect(int.parse(match!.group(1)!), 0);
          final log = await File(fx.cycleLogPath).readAsString();
          expect(log, contains('- no-op: true'));
          expect(log, isNot(contains('actions:')));
        },
      );
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );

  group('US4 — Summary-line contract (T018 / U21, A10-A11)', () {
    final shape = RegExp(
      r'^refactor: feature=(\S+) outcome=(clean|refactored|not-green|regression|runner-error) applied=(\d+)$',
    );

    test('A10: every invocation ends with the summary line '
        '`refactor: feature=<f> outcome=<o> applied=<n>`', () async {
      await fx.seedAlreadyCleanLib();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(refactorArgs(fx));
      final lastLine = out.trim().split('\n').last;
      expect(shape.firstMatch(lastLine), isNotNull, reason: lastLine);
    });

    test(
      'A11: exit code 0 occurs exactly on clean/refactored; all else non-zero',
      () async {
        // Green path → 0.
        await fx.seedAlreadyCleanLib();
        var runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing(refactorArgs(fx));
        expect(exitCode, 0);

        // Red path → non-zero.
        final fxRed = await TddFixture.create();
        try {
          await fxRed.seedRedSuite();
          exitCode = 0;
          runner = CliRunner(exitOnCompletion: false);
          await runner.runCapturing(refactorArgs(fxRed));
          expect(exitCode, isNot(0));
        } finally {
          fxRed.dispose();
          exitCode = 0;
        }
      },
    );

    test('summary line is the FINAL stdout line (no prose after it)', () async {
      await fx.seedAlreadyCleanLib();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(refactorArgs(fx));
      final lines = out.trim().split('\n');
      final last = lines.last;
      expect(
        shape.firstMatch(last),
        isNotNull,
        reason: 'last line was: "$last"\nfull output:\n$out',
      );
    });
  }, timeout: const Timeout(Duration(minutes: 8)));
}

/// Compute a path -> content hash map for every regular file under a tree.
Map<String, String> _checksumTree(String projectRoot, String treeName) {
  final sums = <String, String>{};
  final dir = Directory(p.join(projectRoot, treeName));
  if (!dir.existsSync()) return sums;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File) {
      sums[p.relative(entity.path, from: projectRoot)] = _fingerprint(entity);
    }
  }
  return sums;
}

String _fingerprint(File file) {
  final bytes = file.readAsBytesSync();
  var hash = bytes.length;
  for (final byte in bytes) {
    hash = (hash * 31 + byte) & 0x7fffffff;
  }
  return '${bytes.length}-$hash';
}
