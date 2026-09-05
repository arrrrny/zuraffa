// T001 (issue #970, FR-001 / AC-1): kill the bare `exit(64)` in
// `JsonMockCommand`'s usage-error path.
//
// RED evidence (pre-fix master): `zfa mock json` with no entity name calls
// `dart:io exit(64)` mid-dispatch, which kills the ENTIRE host process —
// an in-process host (MCP server, embedded runner, `dart test` itself)
// dies before it can read the exit code. Running this file pre-fix kills
// the test process with exit 64.
//
// Contract pinned here (remediation): the usage error publishes
// `exitCode = 64` (the slice #767 published-exitCode pattern) and RETURNS,
// so the host survives and observes the exit code.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'mock_cli_guard.dart';

void main() {
  late Directory tempDir;
  var exitCodeAtEntry = 0;

  setUp(() async {
    exitCodeAtEntry = exitCode;
    tempDir = await Directory.systemTemp.createTemp('mock_exit_970_');
  });

  tearDown(() async {
    exitCode = exitCodeAtEntry;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'A1: zfa mock json with no entity survives in-process and sets exit 64',
    () async {
      final runner = CliRunner(exitOnCompletion: false);
      // Pre-fix, the bare exit(64) inside JsonMockCommand kills THIS
      // process before the future below ever completes — reaching the
      // assertions is itself the survival proof.
      final out = await CwdGuard.exclusive(
        () => runner.runCapturing(['-C', tempDir.path, 'mock', 'json']),
      );

      expect(exitCode, 64, reason: 'usage error must publish exit code 64');
      expect(
        out,
        contains('Usage'),
        reason: 'the usage line must still reach the host',
      );
      expect(
        out,
        contains('zfa mock json'),
        reason: 'the usage line must name the command',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('A1b: a follow-up command still runs in the same host process after the '
      'usage refusal (no process death)', () async {
    final runner = CliRunner(exitOnCompletion: false);
    await CwdGuard.exclusive(
      () => runner.runCapturing(['-C', tempDir.path, 'mock', 'json']),
    );
    expect(exitCode, 64);

    // Same host, second dispatch: proves the first refusal did not
    // terminate the process.
    final out2 = await CwdGuard.exclusive(
      () => runner.runCapturing(['-C', tempDir.path, '--help']),
    );
    expect(out2, contains('zfa'));
    expect(
      exitCode,
      0,
      reason:
          'runCapturing resets exitCode per invocation (hermetic) — the '
          '64 from the refusal was observed BEFORE this second dispatch',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
