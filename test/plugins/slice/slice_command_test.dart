@Tags(['slow'])
/// Tests for the `zfa slice` command shell (U65, U66; INV-1).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U65: An unknown subcommand fails with a usage error listing the valid
///        subcommands
///   U66: `cut` without `--entry` fails with a usage error
///
/// INV-1: every `zfa slice` subcommand validates its arguments and fails with
/// usage text, never a stack trace.
library;

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/slice_command.dart';

import 'helpers/capture_output.dart';

void main() {
  late CommandRunner<void> runner;
  late SliceCommand command;

  setUp(() {
    command = SliceCommand();
    runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
  });

  group('SliceCommand argument validation (INV-1)', () {
    test(
      'U65: an unknown subcommand fails with a usage error listing the valid '
      'subcommands',
      () async {
        final output = await captureOutput(
          () => runner.run(['slice', 'teleport']),
        );

        expect(output, contains('Unknown slice subcommand: teleport'));
        expect(output, contains('cut'));
        expect(output, contains('merge'));
        expect(output, contains('list'));
        expect(output, contains('inspect'));
        expect(output, contains('verify'));
        expect(output, contains('run'));
        expect(output, contains('export'));
        expect(output, contains('import'));
        expect(command.exitCode, equals(2));
      },
    );

    test('U66: cut without --entry fails with a usage error', () async {
      final output = await captureOutput(
        () => runner.run(['slice', 'cut', 'profile_feature']),
      );

      expect(output, contains('--entry'));
      expect(
        output,
        contains('Missing --entry'),
        reason: 'the usage error must say what is missing',
      );
      expect(command.exitCode, equals(2));
    });

    test(
      'slice with no arguments prints usage and exits 2 (usage error)',
      () async {
        // Honesty sweep, EPIC 1 #1132: bare `zfa slice` (no subcommand) is a
        // usage error and must exit the CANONICAL 2 (SPEC 917; legacy 64
        // retired). Previously this was a lying-success — the runner printed
        // usage text but returned exitCode 0, hiding the fact that no
        // subcommand was dispatched. Explicit `zfa slice --help` / `-h` keep
        // exiting 0 — help is a successful outcome.
        final output = await captureOutput(() => runner.run(['slice']));

        expect(output, contains('usage: zfa slice'));
        expect(command.exitCode, equals(2));
      },
    );

    test(
      'slice --help and -h still exit 0 (help is a successful outcome)',
      () async {
        final helpOutput = await captureOutput(
          () => runner.run(['slice', '--help']),
        );
        expect(helpOutput, contains('usage: zfa slice'));
        expect(command.exitCode, equals(0));

        final shortHelpOutput = await captureOutput(
          () => runner.run(['slice', '-h']),
        );
        expect(shortHelpOutput, contains('usage: zfa slice'));
        expect(command.exitCode, equals(0));
      },
    );
  });
}
