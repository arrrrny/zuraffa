// Spec #972 — honest bare-command grammar for `zfa usecase` (FR-1).
//
// Bug #856 established the contract for every PluginCommand whose
// positional grammar is unreachable through the CLI (package:args rejects
// a bare entity name as a subcommand attempt before run() executes):
// run()'s only honest behavior is to print the SUBCOMMAND grammar, never
// generate, and signal a usage error (exit 64). `zfa usecase` was left
// behind: it printed "❌ Usage: zfa usecase <EntityName> [options]" and
// returned with exit code 0 — a silent no-op that dresses a usage error
// up as success. This suite pins the honest grammar and the exit code.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

Future<ProcessResult> _runProbe(String commandName) => Process.run(
  Platform.resolvedExecutable,
  ['run', 'test/commands/fixtures/plugin_run_probe.dart', commandName],
  workingDirectory: Directory.current.path,
);

void main() {
  group('spec 972 FR-1 — bare zfa usecase grammar', () {
    test('run() prints the subcommand grammar and exits 64 — never the dead '
        'positional hint, never the generator', () async {
      final result = await _runProbe('usecase');

      expect(
        result.exitCode,
        64,
        reason:
            'a bare-command usage error must not look successful '
            '(silent no-op). stdout=${result.stdout} '
            'stderr=${result.stderr}',
      );
      expect(
        result.stdout,
        contains('<subcommand>'),
        reason: 'run() must point at the live subcommand grammar',
      );
      expect(
        result.stdout,
        isNot(contains('Usage: zfa usecase <EntityName>')),
        reason: 'the unreachable positional hint must be gone',
      );
      expect(
        result.stdout,
        isNot(contains('Generation complete')),
        reason: 'run() must never reach the generator',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('FR-2: dispatch still rejects a bare entity name before run() — '
        'the runner-level contract is unchanged', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['usecase', 'Widget']);
      expect(
        out,
        contains('Could not find a subcommand named "Widget"'),
        reason: 'zfa usecase Widget must stay a dispatch-level error',
      );
    });

    test('FR-3: the no-args CLI invocation still reports the missing '
        'subcommand at dispatch level (regression pin)', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['usecase']);
      expect(out, contains('Missing subcommand'));
      expect(out, contains('zfa usecase <subcommand>'));
    });
  });
}
