// Issue #1918 — `zfa tdd run --baseline-scope <dir>` scoped the run's
// baseline capture but NOT the phase-2 refactor: the driver spawned
// `zfa tdd refactor` without the scope, and the refactor command had no
// `--baseline-scope` to receive one, so its preflight/re-proof resolved the
// profile's full-suite `suite:` template and swept the whole tree.
//
// Behaviors:
//   B1 — the driver hands `--baseline-scope <dir>` to the refactor spawn.
//   B2 — `zfa tdd refactor --baseline-scope <dir>` scopes its preflight
//        suite command to the same path the baseline was captured with.
//   B3 — without the flag the refactor stays full-suite (guard).
//   B4 — the scope must be project-relative (usage refusal).
@Tags(['slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  const feature = '004-login-ui';

  group('command level — refactor honours --baseline-scope', () {
    late TddFixture fx;

    Future<String> runRefactor({List<String> extraArgs = const []}) async {
      final runner = CliRunner(exitOnCompletion: false);
      return runner.runCapturing([
        'tdd',
        'refactor',
        '--project',
        fx.root.path,
        '--feature',
        fx.featureName,
        ...extraArgs,
      ]);
    }

    setUp(() async {
      fx = await TddFixture.create(featureName: feature);
      await fx.seedAlreadyCleanLib();
      // A green test in the scope directory — the scoped suite has
      // something real to run.
      final scopedDir = Directory(p.join(fx.root.path, 'test', 'tdd', feature));
      await scopedDir.create(recursive: true);
      await File(p.join(scopedDir.path, 'scope_test.dart')).writeAsString('''
import 'package:test/test.dart';

void main() {
  test('scoped probe', () => expect(1, 1));
}
''');
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    test('B2/B3: --baseline-scope scopes the refactor preflight; without it '
        'the command stays full-suite', () async {
      final scoped = await runRefactor(
        extraArgs: ['--baseline-scope', 'test/tdd/$feature'],
      );
      expect(CliRunner.lastDispatchedExitCode, 0, reason: scoped);
      // The preflight line names the SAME scope the driving run captured
      // its baseline with.
      expect(
        scoped,
        contains('command: dart test test/tdd/$feature'),
        reason: scoped,
      );

      final unscoped = await runRefactor();
      expect(CliRunner.lastDispatchedExitCode, 0, reason: unscoped);
      expect(unscoped, contains('command: dart test'), reason: unscoped);
      expect(
        unscoped,
        isNot(contains('command: dart test test/tdd/$feature')),
        reason: unscoped,
      );
    });

    test(
      'B4: an absolute --baseline-scope is refused as a usage error',
      () async {
        final out = await runRefactor(
          extraArgs: ['--baseline-scope', p.join(fx.root.path, 'test')],
        );
        expect(CliRunner.lastDispatchedExitCode, isNot(0), reason: out);
        expect(out, contains('--baseline-scope'), reason: out);
        expect(out, contains('relative to the project root'), reason: out);
      },
    );
  });

  group('driver level — the refactor spawn carries the run\'s scope', () {
    late TddFixture dfx;

    setUp(() async {
      dfx = await TddFixture.create(featureName: feature, writeProfile: false);
      await dfx.writeFakeZfa();
    });

    tearDown(() {
      dfx.dispose();
      exitCode = 0;
    });

    test('B1: zfa tdd run --baseline-scope hands the scope to the refactor '
        'spawn', () async {
      await dfx.seedTestList([
        (
          id: 'A1',
          description: 'green unit behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await dfx.registerBehavior(
        id: 'A1',
        description: 'green unit behavior',
        writeTestFile: false,
      );
      await dfx.seedRedEvidence('A1');
      await dfx.seedGreenEvidence('A1');
      await dfx.seedRunState(states: {'A1': 'green'});

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        feature,
        '--project',
        dfx.root.path,
        '--zfa-bin',
        dfx.fakeZfaBin,
        '--baseline-scope',
        'test/tdd/$feature',
      ]);

      expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
      final refactorSpawns = dfx.stepArgvLog().where(
        (l) => l.startsWith('tdd refactor A1'),
      );
      expect(refactorSpawns, isNotEmpty, reason: out);
      for (final line in refactorSpawns) {
        expect(
          line,
          contains('--baseline-scope test/tdd/$feature'),
          reason: line,
        );
      }
    });
  });
}
