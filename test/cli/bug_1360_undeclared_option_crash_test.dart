// Issue #1360 — an UNDECLARED option on a parser-only-registered
// subcommand (bug #856's grammar) crashes package:args' error path with
// a null-check TypeError instead of the clean usage error:
//
//   zfa simulate run --world=v3
//   ❌ Error: Null check operator used on a null value   (exit 1)
//
// Root cause: args 2.7.0 CommandRunner.parse's ArgParserException path
// does `commands[...]!` / `subcommands[...]!` — `run` exists in
// simulate's argParser (addCommand) but NOT in Command.subcommands
// (addSubcommand), so the `!` fires. The crash must become the clean
// usage error (exit 2, "Could not find an option named ...") that the
// parser intended to throw.
//
// Behaviors (test-list):
//   B1 — subcommand-level unknown option → exit 2 + clean message + usage.
//   B2 — parent-level unknown option → exit 2 clean (already resolvable).
//   B3 — valid invocations unaffected (regression guard).
//   B4 — the SPEC 917 `--> fix:` line accompanies the usage error.

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  Future<(int, String)> runZfa(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    final output = await runner.runCapturing(args);
    return (exitCode, output);
  }

  test('B1: an undeclared subcommand option is a clean usage error',
      () async {
    final (code, output) = await runZfa([
      'simulate',
      'run',
      '--world=v3',
    ]);
    expect(code, 2, reason: output);
    expect(output, contains('Could not find an option named "--world"'));
    expect(
      output,
      isNot(contains('Null check operator')),
      reason: 'the package:args crash must never surface',
    );
  });

  test('B2: an undeclared parent-level option stays a clean usage error',
      () async {
    final (code, output) = await runZfa(['simulate', '--world=v3']);
    expect(code, 2, reason: output);
    expect(output, contains('Could not find an option named "--world"'));
    expect(output, isNot(contains('Null check operator')));
  });

  test('B3: valid simulate invocations are unaffected', () async {
    final (helpCode, helpOutput) = await runZfa(['simulate', '--help']);
    expect(helpCode, 0, reason: helpOutput);
    expect(helpOutput, contains('Usage:'));
  });

  test('B4: the usage error carries the SPEC 917 fix line', () async {
    final (code, output) = await runZfa(['simulate', 'run', '--world=v3']);
    expect(code, 2, reason: output);
    expect(output, contains('-->'));
  });
}
