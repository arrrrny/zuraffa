@Tags(['slow'])
// SC-004 acceptance test (spec 046-tdd-verify-red, US4.AC1-AC2 / T016,
// T024, U26): the summary line is the final stdout line in the pinned
// contract format on every code path, and exit code 0 occurs exactly on
// certification.
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

  final summaryShape = RegExp(
    r'^verify-red: behavior=(\S+) classification=(\S+) '
    r'certified=(true|false) feature=(\S+)$',
  );

  /// The last non-empty line of the captured output.
  String lastLine(String out) {
    final lines = out.trim().split('\n');
    return lines.last;
  }

  test('A13/U26: certified run ends with the contract summary line '
      '(final stdout line)', () async {
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runInFixture(runner, fx.root.path, [
      'tdd',
      'verify-red',
      'B-001',
    ]);
    final match = summaryShape.firstMatch(lastLine(out));
    expect(match, isNotNull, reason: 'last line was: ${lastLine(out)}');
    expect(match!.group(1), 'B-001');
    expect(match.group(2), 'assertion');
    expect(match.group(3), 'true');
    expect(match.group(4), '046-tdd-verify-red');
  });

  test(
    'A13/U26: rejected run (unexpected-green) ends with the contract line',
    () async {
      final fx2 = await TddFixture.create();
      try {
        await fx2.registerBehavior(
          id: 'B-001',
          description: description,
          testContent: TddFixture.greenTest(description),
        );
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runInFixture(runner, fx2.root.path, [
          'tdd',
          'verify-red',
          'B-001',
        ]);
        final match = summaryShape.firstMatch(lastLine(out));
        expect(match, isNotNull, reason: 'last line was: ${lastLine(out)}');
        expect(match!.group(2), 'unexpected-green');
        expect(match.group(3), 'false');
      } finally {
        fx2.dispose();
        exitCode = 0;
      }
    },
  );

  test(
    'A13/U26: resolution error ends with the contract line (unresolved)',
    () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runInFixture(runner, fx.root.path, [
        'tdd',
        'verify-red',
        'B-999',
      ]);
      final match = summaryShape.firstMatch(lastLine(out));
      expect(match, isNotNull, reason: 'last line was: ${lastLine(out)}');
      expect(match!.group(1), 'B-999');
      expect(match.group(2), 'unresolved');
      expect(match.group(3), 'false');
    },
  );

  test('A14: exit code 0 occurs exactly on certification; '
      'every rejection is non-zero', () async {
    // Certified -> 0.
    final runner = CliRunner(exitOnCompletion: false);
    await runInFixture(runner, fx.root.path, ['tdd', 'verify-red', 'B-001']);
    expect(exitCode, 0, reason: 'certified red must exit 0');

    // Rejected (unknown id) -> non-zero.
    await runInFixture(runner, fx.root.path, ['tdd', 'verify-red', 'B-999']);
    expect(exitCode, isNot(0), reason: 'resolution failure must be non-zero');

    // Rejected (no candidates after certification) -> non-zero.
    await runInFixture(runner, fx.root.path, ['tdd', 'verify-red']);
    expect(
      exitCode,
      isNot(0),
      reason:
          'zero-candidate no-arg invocation must be non-zero '
          '(B-001 now has red evidence)',
    );
  });
}
