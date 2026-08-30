@Tags(['slow'])
// SC-002 acceptance test (spec 046-tdd-verify-red, US2.AC1-AC5 / T022):
// every dishonest-red class is rejected — non-zero exit, named
// classification, cycle log unchanged — through the real CLI.
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/commands/verify_red_command.dart'
    show zfaTddWorkingDirectory;

import '../helpers/tdd_fixture.dart';

void main() {
  /// Zone-pins the CLI run to the fixture project — no process-wide
  /// `Directory.current` mutation (concurrent test files share one cwd).
  Future<String> runInFixture(
    CliRunner runner,
    String root,
    List<String> args,
  ) => runZoned(
    () => runner.runCapturing(args),
    zoneValues: {zfaTddWorkingDirectory: root},
  );

  const description = 'returns 42 when invoked with no args';

  setUp(() {});

  tearDown(() {
    exitCode = 0;
  });

  test('A4: compile-broken test -> compile-error, log unchanged', () async {
    final fx = await TddFixture.create(featureName: '046-tdd-verify-red');
    try {
      await fx.registerBehavior(
        id: 'B-001',
        description: description,
        testContent: TddFixture.compileErrorTest(description),
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runInFixture(runner, fx.root.path, [
        'tdd',
        'verify-red',
        'B-001',
      ]);
      expect(out, contains('classification=compile-error certified=false'));
      expect(exitCode, isNot(0));
      expect(File(fx.cycleLogPath).existsSync(), isFalse);
    } finally {
      fx.dispose();
    }
  });

  test('A5: missing test file -> load-error, log unchanged', () async {
    final fx = await TddFixture.create(featureName: '046-tdd-verify-red');
    try {
      await fx.registerBehavior(
        id: 'B-001',
        description: description,
        writeTestFile: false,
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runInFixture(runner, fx.root.path, [
        'tdd',
        'verify-red',
        'B-001',
      ]);
      expect(out, contains('classification=load-error certified=false'));
      expect(exitCode, isNot(0));
      expect(File(fx.cycleLogPath).existsSync(), isFalse);
    } finally {
      fx.dispose();
    }
  });

  test('A6: passing test -> unexpected-green, log unchanged', () async {
    final fx = await TddFixture.create(featureName: '046-tdd-verify-red');
    try {
      await fx.registerBehavior(
        id: 'B-001',
        description: description,
        testContent: TddFixture.greenTest(description),
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runInFixture(runner, fx.root.path, [
        'tdd',
        'verify-red',
        'B-001',
      ]);
      expect(out, contains('classification=unexpected-green certified=false'));
      expect(exitCode, isNot(0));
      expect(File(fx.cycleLogPath).existsSync(), isFalse);
    } finally {
      fx.dispose();
    }
  });

  test('A7: skipped test -> skipped, log unchanged', () async {
    final fx = await TddFixture.create(featureName: '046-tdd-verify-red');
    try {
      await fx.registerBehavior(
        id: 'B-001',
        description: description,
        testContent: TddFixture.skippedTest(description),
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runInFixture(runner, fx.root.path, [
        'tdd',
        'verify-red',
        'B-001',
      ]);
      expect(out, contains('classification=skipped certified=false'));
      expect(exitCode, isNot(0));
      expect(File(fx.cycleLogPath).existsSync(), isFalse);
    } finally {
      fx.dispose();
    }
  });

  test(
    'A8: runner cannot execute exactly the target test -> runner-error',
    () async {
      // Blended run: the registered name matches two tests in the file.
      final fx = await TddFixture.create(featureName: '046-tdd-verify-red');
      try {
        await fx.registerBehavior(
          id: 'B-001',
          description: 'returns 42',
          testContent: TddFixture.blendedTest(
            'returns 42 when invoked with no args',
            'returns 42 when invoked with some args',
          ),
        );
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runInFixture(runner, fx.root.path, [
          'tdd',
          'verify-red',
          'B-001',
        ]);
        expect(out, contains('classification=runner-error certified=false'));
        expect(exitCode, isNot(0));
        expect(File(fx.cycleLogPath).existsSync(), isFalse);
      } finally {
        fx.dispose();
      }
    },
  );
}
