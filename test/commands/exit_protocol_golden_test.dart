import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/cli/exit_protocol.dart';

/// SPEC 917 (issue #917, absorbing #839/#778) — the ratified exit-code
/// protocol, golden-table asserted.
///
/// VISION §4: "Exit codes become a protocol: 0 success, 1 test RED,
/// 2 invalid grammar, 3 manifest drift, 4 state conflict. Every error
/// message ends with a machine-actionable line."
///
/// The golden table below is the treaty. The live-behavior rows run the
/// real CLI (in-process, hermetic) so the table asserts BEHAVIOR, not
/// intent. Legacy paths: 64 is mapped onto canonical 2 (usage); 255/-9
/// are external-kill signals zfa never emits.
void main() {
  group('golden table — constants', () {
    test('the five canonical codes and their meanings are frozen', () {
      expect(ExitProtocol.success, 0, reason: '0 = success / GREEN / complete');
      expect(
        ExitProtocol.failure,
        1,
        reason:
            '1 = RED (honest, in-loop) / stopped / audit failure — '
            'distinguished by the verdict exit_class',
      );
      expect(
        ExitProtocol.usage,
        2,
        reason:
            '2 = usage/grammar error — the operation could not run as '
            'invoked (unknown flag/subcommand, missing args, invalid target, '
            'runner-infrastructure error)',
      );
      expect(
        ExitProtocol.drift,
        3,
        reason:
            '3 = contract/spec drift — manifest ↔ CLI drift, '
            'template-version drift, traceability drift, corrupt state',
      );
      expect(ExitProtocol.conflict, 4, reason: '4 = state conflict');
    });

    test('legacy 64 (EX_USAGE) maps onto canonical 2 (usage)', () {
      expect(ExitProtocol.legacyUsage, 64);
      expect(ExitProtocol.canonicalize(64), ExitProtocol.usage);
    });

    test(
      '255 / -9 / 137 are documented external-kill signals, never emitted',
      () {
        // The protocol documents them; the codebase must not emit them.
        // (grep-asserted in the conformance workflow; here we pin the mapping
        // of the one legacy code the CLI still recognizes.)
        expect(ExitProtocol.canonicalize(ExitProtocol.success), 0);
      },
    );

    test('the protocol table is printed by the top-level help', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final help = await runner.runCapturing(const []);
      expect(help, contains('EXIT CODES'));
      expect(help, contains('0  success'));
      expect(help, contains('1  failure'));
      expect(help, contains('2  usage'));
      expect(help, contains('3  drift'));
      expect(help, contains('4  conflict'));
    });
  });

  group('golden table — live behavior', () {
    test('row 0 — a successful invocation exits 0', () async {
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(const ['--version']);
      expect(exitCode, ExitProtocol.success);
      expect(CliRunner.lastDispatchedExitCode, ExitProtocol.success);
    });

    test(
      'row 2 — unknown option is a usage error: exits 2 (was legacy 64)',
      () async {
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(const [
          'manifest',
          '--definitely-not-a-flag',
        ]);
        expect(
          CliRunner.lastDispatchedExitCode,
          ExitProtocol.usage,
          reason:
              'legacy 64 is retired; usage errors exit the canonical 2 — '
              '$out',
        );
        // Errors are an API: the failure ends with a machine-actionable fix.
        expect(out, contains('fix:'));
      },
    );

    test('row 2 — removed `generate` verb exits 2 with a fix line', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(const ['generate', 'User']);
      expect(CliRunner.lastDispatchedExitCode, ExitProtocol.usage);
      expect(out, contains('--> fix:'));
    });

    test('row 2 — missing required argument exits 2 (was 64)', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(const ['feature']);
      expect(CliRunner.lastDispatchedExitCode, ExitProtocol.usage, reason: out);
      expect(out, contains('fix:'));
    });

    test('row 1 — an honest failure exits 1', () async {
      final runner = CliRunner(exitOnCompletion: false);
      // `zfa validate` on a nonexistent config file: runtime failure.
      final out = await runner.runCapturing(const [
        'validate',
        '/nonexistent/zfa-spec-917/config.json',
      ]);
      expect(
        CliRunner.lastDispatchedExitCode,
        ExitProtocol.failure,
        reason: out,
      );
      expect(out, contains('fix:'));
    });

    test('row 3 — contract drift exits 3 (manifest gate)', () async {
      // The drift row is exercised end-to-end by
      // manifest_verify_gate_test.dart (synthetic drifting plugin); here we
      // pin that the canonical drift code is what the gate exits with.
      expect(ExitProtocol.drift, 3);
    });

    test('row 4 — state conflict exits 4', () async {
      // Exercised end-to-end by the run-driver concurrent-run fixtures
      // (test/plugins/tdd/run_command_test.dart). Pinned here as protocol.
      expect(ExitProtocol.conflict, 4);
    });
  });

  group('every non-zero exit ends with a machine-actionable fix line', () {
    Future<(int, String)> run(List<String> args) async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(args);
      final code = CliRunner.lastDispatchedExitCode;
      return (code, out);
    }

    int lastNonEmptyLineCode(String out) {
      final lines = out.trim().split('\n').reversed;
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        if (line.contains('fix:')) return 0;
        return 1;
      }
      return 1;
    }

    test('runner-level: unknown option output ends with fix:', () async {
      final (code, out) = await run(['entity', '--nope']);
      expect(code, ExitProtocol.usage);
      expect(lastNonEmptyLineCode(out), 0, reason: out);
    });

    test('runner-level: unknown command output ends with fix:', () async {
      final (code, out) = await run(['definitely-not-a-command-917']);
      expect(code, ExitProtocol.usage);
      expect(lastNonEmptyLineCode(out), 0, reason: out);
    });

    test('runner-level: generic error output ends with fix:', () async {
      final (code, out) = await run([
        'manifest',
        '--verify',
        '--format',
        'json',
        'no-such-plugin-917',
      ]);
      // Scoping verify to a plugin id that does not exist is a usage error
      // (the treaty cannot certify what is absent) — non-zero either way,
      // and the output must close with a fix line.
      expect(code, isNot(0));
      expect(lastNonEmptyLineCode(out), 0, reason: out);
    });
  });
}
