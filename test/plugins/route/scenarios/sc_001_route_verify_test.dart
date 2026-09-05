// O1: `zfa route verify` is reachable as a top-level subcommand and the
// runner can be invoked end-to-end with the verify path.
//
// The detailed JSON shape is pinned in `route_table_test.dart` (U1).
// The drift logic is pinned in `route_drift_detector_test.dart` (U2).
// The plain/emoji-free text is pinned in `output_format_plain_test.dart` (U3).
// The CLI surface (subcommand + flags) is pinned in `route_command_test.dart` (U4).
// This scenario only asserts the end-to-end command is runnable.
//
// BUG 1060: the old expectation — exit 0 on a project with no route inputs
// — was the lie-certifying PASS this bug removes. An empty project is an
// `insufficient-input` verdict (exit 2), never a silent PASS.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/route_command.dart';
import 'package:zuraffa/src/plugins/route/route_plugin.dart';

void main() {
  test(
    'O1: zfa route verify executes end-to-end and reports insufficient-input (exit 2) on an empty project',
    () async {
      exitCode = 0;
      final runner = CommandRunner<void>('zfa', 'test')
        ..addCommand(RouteCommand(RoutePlugin(outputDir: 'lib/src')));
      await runner.run(['route', 'verify']);
      expect(
        exitCode,
        equals(2),
        reason:
            'no route inputs is insufficient-input (exit 2), never a silent PASS (#1060)',
      );
    },
  );
}
