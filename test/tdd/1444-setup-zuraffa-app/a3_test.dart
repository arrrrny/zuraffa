// Acceptance test A3 — spec 1444-setup-zuraffa-app (PR #1462).
//
// source_criterion: AC-3 — pure-Dart projects have no Flutter shell to
// generate: the app-shell step prints its documented skip line so the
// flow's numbering stays contiguous (step 8 of 9) and nothing is written.
library;

import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/setup_command.dart';

void main() {
  group('A3 (AC-3): pure-Dart setup skips the app shell explicitly', () {
    test('prints the documented skip line and no shell would-write', () async {
      final runner = CommandRunner('zfa', 'test')..addCommand(SetupCommand());
      final prints = <String>[];
      await runZoned(
        () => runner.run(['setup', 'demo_lib', '--dry-run', '--dart']),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, message) => prints.add(message),
        ),
      );
      final out = prints.join('\n');

      expect(out, contains('[8/9] Skipping app shell (pure-Dart project).'));
      expect(out, isNot(contains('Generating app shell (ZuraffaApp)')));
      expect(out, isNot(contains('app_router.dart')));
    });
  });
}
