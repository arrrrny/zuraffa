@Tags(['slow'])
// Issue #1589 — parked contracts poison the phase-2 refactor gate.
//
// The run's suite baseline (issue #741) is captured BEFORE the first gen, so
// a contract parked at BLOCKED during THIS run fails its seam test with a
// failure the baseline has never seen — issue #922's tolerance only excludes
// baseline-recorded failures, so every phase-2 `refactor` spawn refuses
// (`not-green`), the driver skips the refactor for EVERY green behavior, and
// the pass is silently lost for the whole feature.
//
// Fix under test: the driving run hands the parked seams it knows about to
// every refactor spawn (`--parked-seam <test-path>`), and refactor tolerates
// suite failures whose file matches a parked seam in BOTH the preflight and
// the re-proof — pre-existing-failure economics for the parked verdict. The
// tolerance is surgical (a NEW failure in any other file still refuses /
// regresses), unparseable transcripts still fail closed, and a flag-less
// standalone refactor keeps the absolute-green contract (spec 048 FR-001).
//
// Fast tier: the profile's suite command is a spy script (the bug #922
// pattern) — no `dart test` spawn (kernel-cache-safe fixture rule).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  late String fakeZfa;
  const feature = '090-tdd-fixture';

  /// The parked contract's seam file — the file whose failure the gate must
  /// learn to tolerate when the driver hands it over.
  Future<String> seedParkedSeam() async {
    final path = p.join(
      fx.root.path,
      'test',
      'tdd',
      feature,
      'contract_a1_test.dart',
    );
    await File(path).parent.create(recursive: true);
    await File(path).writeAsString('// kind: contract\nvoid main() {}\n');
    return path;
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    fakeZfa = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  List<String> refactorArgs({List<String> extra = const []}) => [
    'tdd',
    'refactor',
    '--project',
    fx.root.path,
    '--zfa-bin',
    fakeZfa,
    ...extra,
  ];

  group('refactor: parked-seam tolerance (issue #1589)', () {
    test('a preflight red whose ONLY failure lives in a handed parked seam '
        'is tolerated (outcome=clean, exit 0)', () async {
      await seedParkedSeam();
      await fx.rewriteProfile(
        singleTemplate: TddFixture.defaultSingleTemplate,
        suiteTemplate: await fx.writeSpyScript(
          'parked-red-suite',
          output:
              '00:00 +0 -1: test/tdd/$feature/contract_a1_test.dart: '
              'User.validateEmail blocked contract [E]\n'
              '00:00 +0 -1: Some tests failed.',
          exit: '1',
        ),
      );
      await fx.seedAlreadyCleanLib();
      final checksumsBefore = fx.checksumTestAndLib();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        refactorArgs(
          extra: ['--parked-seam', 'test/tdd/$feature/contract_a1_test.dart'],
        ),
      );

      expect(out, contains('outcome=clean'), reason: out);
      expect(out, contains('parked contract'), reason: out);
      expect(exitCode, 0, reason: out);
      expect(fx.checksumTestAndLib(), equals(checksumsBefore));
    });

    test('WITHOUT the flag the same red still refuses — the flag-less '
        'standalone contract stays absolute-green (spec 048 FR-001)', () async {
      await seedParkedSeam();
      await fx.rewriteProfile(
        singleTemplate: TddFixture.defaultSingleTemplate,
        suiteTemplate: await fx.writeSpyScript(
          'parked-red-suite',
          output:
              '00:00 +0 -1: test/tdd/$feature/contract_a1_test.dart: '
              'User.validateEmail blocked contract [E]\n'
              '00:00 +0 -1: Some tests failed.',
          exit: '1',
        ),
      );
      await fx.seedAlreadyCleanLib();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(refactorArgs());

      expect(out, contains('outcome=not-green'), reason: out);
      expect(exitCode, isNot(0), reason: out);
    });

    test('a NEW failure beyond the handed parked seam still refuses — the '
        'tolerance is surgical', () async {
      await seedParkedSeam();
      await fx.rewriteProfile(
        singleTemplate: TddFixture.defaultSingleTemplate,
        suiteTemplate: await fx.writeSpyScript(
          'mixed-red-suite',
          output:
              '00:00 +0 -1: test/tdd/$feature/contract_a1_test.dart: '
              'User.validateEmail blocked contract [E]\n'
              '00:00 +0 -1: test/other/fresh_test.dart: fresh genuine '
              'failure [E]\n'
              '00:00 +0 -1: Some tests failed.',
          exit: '1',
        ),
      );
      await fx.seedAlreadyCleanLib();
      final checksumsBefore = fx.checksumTestAndLib();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        refactorArgs(
          extra: ['--parked-seam', 'test/tdd/$feature/contract_a1_test.dart'],
        ),
      );

      expect(out, contains('outcome=not-green'), reason: out);
      expect(out, contains('fresh genuine failure'), reason: out);
      expect(exitCode, isNot(0), reason: out);
      expect(fx.checksumTestAndLib(), equals(checksumsBefore));
    });

    test('a parked-seam failure BESIDE baseline-recorded failures is '
        'tolerated too (the #922 and #1589 economics compose)', () async {
      await seedParkedSeam();
      final baseline = File(fx.runBaselinePath);
      await baseline.parent.create(recursive: true);
      await baseline.writeAsString(
        jsonEncode({
          'command': 'dart test',
          'exitCode': 1,
          'failedTests': ['test/other/legacy_test.dart: legacy failure'],
          'capturedAt': '2026-09-13T00:00:00.000Z',
          'parseable': true,
        }),
      );
      await fx.rewriteProfile(
        singleTemplate: TddFixture.defaultSingleTemplate,
        suiteTemplate: await fx.writeSpyScript(
          'mixed-baseline-suite',
          output:
              '00:00 +0 -1: test/other/legacy_test.dart: legacy failure [E]\n'
              '00:00 +0 -1: test/tdd/$feature/contract_a1_test.dart: '
              'User.validateEmail blocked contract [E]\n'
              '00:00 +0 -1: Some tests failed.',
          exit: '1',
        ),
      );
      await fx.seedAlreadyCleanLib();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        refactorArgs(
          extra: [
            '--suite-baseline',
            fx.runBaselinePath,
            '--parked-seam',
            'test/tdd/$feature/contract_a1_test.dart',
          ],
        ),
      );

      expect(out, contains('outcome=clean'), reason: out);
      expect(exitCode, 0, reason: out);
    });

    test('a re-proof red confined to the handed parked seam is NOT a '
        'regression (outcome=refactored, exit 0)', () async {
      await seedParkedSeam();
      // The preflight tolerates the parked seam (the ONLY failure), the
      // passes change lib/ (the malformed subject the format/fix passes
      // rewrite), and the re-proof sees the SAME parked failure — a green
      // pass must certify instead of grading the parked verdict a
      // regression.
      await fx.rewriteProfile(
        singleTemplate: TddFixture.defaultSingleTemplate,
        suiteTemplate: await fx.writeSpyScript(
          'parked-both-suite',
          output:
              '00:00 +0 -1: test/tdd/$feature/contract_a1_test.dart: '
              'User.validateEmail blocked contract [E]\n'
              '00:00 +0 -1: Some tests failed.',
          exit: '1',
        ),
      );
      await fx.seedMalformedLib();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        refactorArgs(
          extra: ['--parked-seam', 'test/tdd/$feature/contract_a1_test.dart'],
        ),
      );

      expect(out, contains('outcome=refactored'), reason: out);
      expect(exitCode, 0, reason: out);
      final log = await File(fx.cycleLogPath).readAsString();
      expect(log, contains('tolerated'), reason: log);
    });

    test('an UNPARSEABLE red is never parked-tolerated — fail closed '
        '(outcome=not-green)', () async {
      await seedParkedSeam();
      await fx.rewriteProfile(
        singleTemplate: TddFixture.defaultSingleTemplate,
        suiteTemplate: await fx.writeSpyScript(
          'broken-suite',
          output: 'boom — no parseable transcript here',
          exit: '1',
        ),
      );
      await fx.seedAlreadyCleanLib();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        refactorArgs(
          extra: ['--parked-seam', 'test/tdd/$feature/contract_a1_test.dart'],
        ),
      );

      expect(out, contains('outcome=not-green'), reason: out);
      expect(exitCode, isNot(0), reason: out);
    });
  });
}
