@Tags(['e2e'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/cli/exit_protocol.dart';

/// SPEC 1132 / EPIC 1 lane 1 — the exit-code sweep's last lying commands.
///
/// The 2026-09-17 fleet audit found six commands whose bare (or
/// unknown-subcommand) invocation prints a usage block and exits 0 — the
/// "lying success" pattern the #856/#1239 sweeps eliminated for the rest
/// of the fleet. This suite pins the SPEC 917 contract for the five
/// commands whose lying arms are `return`-based (in-process safe):
/// `cli`, `benchmark`, `bone`, `migrate`, `plugin`.
///
/// The hard-`exit()` arms (`config` bare/unknown/set, `plugin enable`
/// without an id, `plugin <unknown>`) CANNOT be driven in-process
/// pre-fix — a hard exit kills the test isolate — so their RED evidence
/// and subprocess pins live in
/// `test/regression/issue_1132_bare_exit_code_fleet_test.dart`, and their
/// embedded-dispatch-safety assertions live in
/// `config_plugin_embedded_dispatch_1132_test.dart` (added with the fix:
/// the arms return via `exitCode`, never `exit()`).
void main() {
  late CliRunner runner;

  setUp(() {
    runner = CliRunner(exitOnCompletion: false);
  });

  tearDown(() {
    exitCode = 0;
  });

  Future<String> drive(List<String> args) => runner.runCapturing(args);

  group('SPEC 1132 L1 — bare invocations exit usage (2), not 0', () {
    test('bare `zfa cli` prints usage and exits 2', () async {
      final out = await drive(['cli']);

      expect(out, contains('Usage: zfa cli'));
      expect(
        CliRunner.lastDispatchedExitCode,
        ExitProtocol.usage,
        reason:
            '`zfa cli` with no entity is a usage error (SPEC 917): it '
            'must exit ${ExitProtocol.usage}, never 0 — the EPIC 1 '
            'honesty-sweep contract.\nstdout:\n$out',
      );
    });

    test('bare `zfa benchmark` prints usage and exits 2', () async {
      final out = await drive(['benchmark']);

      expect(out, contains('usage: zfa benchmark SUBCOMMAND'));
      expect(
        CliRunner.lastDispatchedExitCode,
        ExitProtocol.usage,
        reason:
            'bare `zfa benchmark` is a usage error: exit '
            '${ExitProtocol.usage}, not 0 (issue #1132 fleet sweep).',
      );
    });

    test('`zfa benchmark --help` still exits 0 (help is success)', () async {
      final out = await drive(['benchmark', '--help']);

      expect(out, contains('usage: zfa benchmark SUBCOMMAND'));
      expect(
        CliRunner.lastDispatchedExitCode,
        ExitProtocol.success,
        reason: 'an explicit --help request is a successful outcome',
      );
    });

    test('bare `zfa bone` prints usage and exits 2', () async {
      final out = await drive(['bone']);

      expect(out, contains('usage: zfa bone SUBCOMMAND'));
      expect(
        CliRunner.lastDispatchedExitCode,
        ExitProtocol.usage,
        reason:
            'bare `zfa bone` is a usage error: exit '
            '${ExitProtocol.usage}, not 0 (issue #1132 fleet sweep).',
      );
    });

    test('`zfa bone <unknown>` prints usage and exits 2', () async {
      final out = await drive(['bone', 'not-a-subcommand']);

      expect(out, contains('Unknown bone subcommand: not-a-subcommand'));
      expect(
        CliRunner.lastDispatchedExitCode,
        ExitProtocol.usage,
        reason:
            'an unknown subcommand is a usage error: exit '
            '${ExitProtocol.usage}, not 0 (issue #1132 fleet sweep).',
      );
    });

    test('`zfa bone --help` still exits 0 (help is success)', () async {
      final out = await drive(['bone', '--help']);

      expect(out, contains('usage: zfa bone SUBCOMMAND'));
      expect(CliRunner.lastDispatchedExitCode, ExitProtocol.success);
    });

    test('bare `zfa migrate` prints usage and exits 2', () async {
      final out = await drive(['migrate']);

      expect(out, contains('USAGE: zfa migrate <target>'));
      expect(
        CliRunner.lastDispatchedExitCode,
        ExitProtocol.usage,
        reason:
            'bare `zfa migrate` is a usage error: exit '
            '${ExitProtocol.usage}, not 0 (issue #1132 fleet sweep).',
      );
    });

    test('`zfa migrate <unknown>` prints usage and exits 2', () async {
      final out = await drive(['migrate', 'not-a-target']);

      expect(out, contains('Unknown migration target: not-a-target'));
      expect(
        CliRunner.lastDispatchedExitCode,
        ExitProtocol.usage,
        reason:
            'an unknown migration target is a usage error: exit '
            '${ExitProtocol.usage}, not 0 — it was exit 0 before the '
            'sweep (issue #1132).',
      );
    });

    test('bare `zfa plugin` prints usage and exits 2', () async {
      final out = await drive(['plugin']);

      expect(out, contains('zfa plugin - Manage ZFA plugins'));
      expect(
        CliRunner.lastDispatchedExitCode,
        ExitProtocol.usage,
        reason:
            'bare `zfa plugin` is a usage error: exit '
            '${ExitProtocol.usage}, not 0 (issue #1132 fleet sweep).',
      );
    });

    test('`zfa plugin --help` still exits 0 (help is success)', () async {
      final out = await drive(['plugin', '--help']);

      expect(out, contains('zfa plugin - Manage ZFA plugins'));
      expect(CliRunner.lastDispatchedExitCode, ExitProtocol.success);
    });
  });
}
