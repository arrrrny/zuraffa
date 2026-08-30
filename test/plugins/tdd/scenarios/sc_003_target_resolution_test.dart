// SC-003 acceptance test (spec 046-tdd-verify-red, US3.AC1-AC4 / T023):
// unambiguous target resolution — single-candidate inference, ambiguity
// rejection with a candidate list, unknown id, and gen-first guidance.
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

  late TddFixture fx;
  const description = 'returns 42 when invoked with no args';

  setUp(() async {
    fx = await TddFixture.create(featureName: '046-tdd-verify-red');
    await fx.registerBehavior(id: 'B-001', description: description);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test(
    'A9: no-arg with exactly one uncertified gen\'d behavior verifies it',
    () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runInFixture(runner, fx.root.path, [
        'tdd',
        'verify-red',
      ]);
      expect(
        out,
        contains(
          'verify-red: behavior=B-001 classification=assertion '
          'certified=true feature=046-tdd-verify-red',
        ),
      );
      expect(exitCode, 0);
    },
  );

  test(
    'A10: no-arg with multiple candidates exits non-zero listing ids',
    () async {
      await fx.registerBehavior(id: 'B-002', description: description);
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runInFixture(runner, fx.root.path, [
        'tdd',
        'verify-red',
      ]);
      expect(exitCode, isNot(0));
      expect(out, contains('B-001'));
      expect(out, contains('B-002'));
      expect(File(fx.cycleLogPath).existsSync(), isFalse);
    },
  );

  test('A11: unknown id exits non-zero naming the id before any run', () async {
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runInFixture(runner, fx.root.path, [
      'tdd',
      'verify-red',
      'B-999',
    ]);
    expect(exitCode, isNot(0));
    expect(out, contains('B-999'));
    expect(File(fx.cycleLogPath).existsSync(), isFalse);
  });

  test(
    'A12: test-list id without registry artifacts instructs gen first',
    () async {
      await File('${fx.featureDir}/tdd/test-list.md').writeAsString('''
# Test List

| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| B-777 | planned but not generated | FR-007 | unit | PENDING | x |
''');
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runInFixture(runner, fx.root.path, [
        'tdd',
        'verify-red',
        'B-777',
      ]);
      expect(exitCode, isNot(0));
      expect(out, contains('zfa tdd gen B-777'));
    },
  );
}
