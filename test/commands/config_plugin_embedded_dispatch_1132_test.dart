@Tags(['e2e'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/cli/exit_protocol.dart';

/// SPEC 1132 / EPIC 1 lane 1 (embedded-dispatch half) — the config and
/// plugin arms that hard-called `exit()` before the sweep.
///
/// A hard `exit()` kills the host isolate: in-process (MCP/embedded)
/// dispatch of `zfa config …` could terminate the embedding process.
/// Post-fix every arm returns via `exitCode`, so driving them through
/// `CliRunner.runCapturing` (in-process) must complete and report the
/// right exit class. Pre-fix these invocations killed the test isolate —
/// which is exactly why their RED evidence lives in the subprocess fleet
/// suite (`test/regression/issue_1132_bare_exit_code_fleet_test.dart`).
///
/// Also pins the exit-CLASS corrections: usage-class refusals
/// (unknown subcommand, missing key/value, missing plugin id) now exit
/// `2` (SPEC 917), not the failure `1` they filed under before.
void main() {
  late CliRunner runner;
  late Directory tmp;

  setUp(() async {
    runner = CliRunner(exitOnCompletion: false);
    tmp = await Directory.systemTemp.createTemp('embedded_1132_');
  });

  tearDown(() async {
    exitCode = 0;
    if (tmp.existsSync()) {
      try {
        await tmp.delete(recursive: true);
      } on FileSystemException {
        // Best-effort cleanup.
      }
    }
  });

  Future<String> drive(List<String> args) =>
      runner.runCapturing(['-C', tmp.path, ...args]);

  group('SPEC 1132 L1 — zfa config arms return via exitCode (no exit())', () {
    test('bare `zfa config` prints usage and exits 2, in-process', () async {
      final out = await drive(['config']);

      expect(out, contains('zfa config - Manage ZFA configuration'));
      expect(
        CliRunner.lastDispatchedExitCode,
        ExitProtocol.usage,
        reason:
            'bare config is a usage error (SPEC 917). The dispatch also '
            'RETURNED — pre-fix this arm hard-called exit(0) and killed '
            'the embedding isolate.\nstdout:\n$out',
      );
    });

    test('`zfa config <unknown>` exits usage 2 (was failure 1)', () async {
      final out = await drive(['config', 'not-a-subcommand']);

      expect(out, contains('Unknown config command: not-a-subcommand'));
      expect(CliRunner.lastDispatchedExitCode, ExitProtocol.usage);
    });

    test('`zfa config set` with no key/value exits usage 2 (was 1)', () async {
      final out = await drive(['config', 'set']);

      expect(out, contains('Usage: zfa config set <key> <value>'));
      expect(CliRunner.lastDispatchedExitCode, ExitProtocol.usage);
    });

    test('`zfa config init <missing-dir>` exits usage 2 in-process', () async {
      final out = await drive(['config', 'init', 'no-such-dir-anywhere']);

      expect(out, contains('Directory not found'));
      expect(CliRunner.lastDispatchedExitCode, ExitProtocol.usage);
    });
  });

  group('SPEC 1132 L1 — zfa plugin arms return via exitCode (no exit())', () {
    test('`zfa plugin <unknown>` exits usage 2 (was failure 1)', () async {
      final out = await drive(['plugin', 'not-an-action']);

      expect(out, contains('Unknown plugin command: not-an-action'));
      expect(
        CliRunner.lastDispatchedExitCode,
        ExitProtocol.usage,
        reason:
            'unknown subcommand is a usage error; the dispatch also '
            'RETURNED (pre-fix: hard exit(1)).\nstdout:\n$out',
      );
    });

    test(
      '`zfa plugin enable` with no id exits usage 2 (was failure 1)',
      () async {
        final out = await drive(['plugin', 'enable']);

        expect(out, contains('Missing plugin id'));
        expect(CliRunner.lastDispatchedExitCode, ExitProtocol.usage);
      },
    );
  });
}
