// Bug #856 contract — dead positional grammar.
//
// Every `PluginCommand` auto-registers its capabilities as subcommands, so
// package:args rejects a bare entity name (`zfa repository Widget`) — and
// any flags-then-positional shape (`zfa repository --methods get Widget`) —
// with "Could not find a subcommand" BEFORE the command's run() ever
// executes. run() is therefore reachable only via direct (programmatic)
// invocation, and its only honest behavior is to print the SUBCOMMAND
// grammar, never generate, and signal a usage error (exit 64). The usage
// strings may no longer advertise the unreachable positional grammar.
//
// The contract runs each real command's run() in a SUBPROCESS (the probe
// fixture): on master the mock command's no-args branch calls exit(64),
// which would otherwise kill the test runner, and the subprocess cleanly
// observes output + exit code for every command alike.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

/// The unreachable positional usage string each command advertised on
/// master (bug #856 evidence), keyed by CLI command name.
const _deadUsageStrings = <String, String>{
  'repository': 'Usage: zfa repository <EntityName>',
  'provider': 'Usage: zfa provider <EntityName>',
  'service': 'Usage: zfa service <ServiceName>',
  'mock': 'Usage: zfa mock <EntityName>',
  'state': 'Usage: zfa state <EntityName>',
  'test': 'Usage: zfa test <EntityName>',
  'sqlite': 'Usage: zfa sqlite [adapter] <EntityName>',
  'route': 'Usage: zfa route <EntityName>',
  'di': 'Usage: zfa di <Name>',
};

Future<ProcessResult> _runProbe(String commandName) => Process.run(
  Platform.resolvedExecutable,
  ['run', 'test/commands/fixtures/plugin_run_probe.dart', commandName],
  workingDirectory: Directory.current.path,
);

void main() {
  group('dead positional grammar (bug #856)', () {
    for (final entry in _deadUsageStrings.entries) {
      test(
        'FR-1: ${entry.key} run() prints the subcommand grammar and exits 64 — '
        'never the dead positional hint, never the generator',
        () async {
          final result = await _runProbe(entry.key);

          expect(
            result.exitCode,
            64,
            reason:
                'a usage error must not look successful; '
                'stdout=${result.stdout} stderr=${result.stderr}',
          );
          expect(
            result.stdout,
            contains('<subcommand>'),
            reason: 'run() must point at the live subcommand grammar',
          );
          expect(
            result.stdout,
            isNot(contains(entry.value)),
            reason: 'the unreachable positional hint must be gone',
          );
          expect(
            result.stdout,
            isNot(contains('Generation complete')),
            reason: 'run() must never reach the generator',
          );
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }

    test('FR-2: dispatch still rejects a bare entity name before run() — '
        'the runner-level contract is unchanged', () async {
      final runner = CliRunner(exitOnCompletion: false);
      for (final name in _deadUsageStrings.keys) {
        final out = await runner.runCapturing([name, 'Widget']);
        expect(
          out,
          contains('Could not find a subcommand named "Widget"'),
          reason: 'zfa $name Widget must stay a dispatch-level error',
        );
      }
    });

    test(
      'FR-3: the no-args CLI invocation still reports the missing subcommand '
      'at dispatch level (regression pin)',
      () async {
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(['repository']);
        expect(out, contains('Missing subcommand'));
        expect(out, contains('zfa repository <subcommand>'));
      },
    );
  });
}
