// Acceptance test A1 — spec 1444-setup-zuraffa-app (PR #1462).
//
// source_criterion: AC-1 — `zfa setup` for a Flutter project generates the
// ZuraffaApp shell automatically; dry-run previews the step and the files
// it would write (lib/main.dart, lib/src/app/my_app.dart,
// lib/src/routing/app_router.dart) without touching the filesystem.
library;

import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/setup_command.dart';

void main() {
  group('A1 (AC-1): setup dry-run previews the ZuraffaApp shell', () {
    test(
      'prints the shell step and the would-write lines for Flutter',
      () async {
        final runner = CommandRunner('zfa', 'test')..addCommand(SetupCommand());
        final prints = <String>[];
        await runZoned(
          () => runner.run(['setup', 'demo_app', '--dry-run', '--flutter']),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, message) => prints.add(message),
          ),
        );
        final out = prints.join('\n');

        expect(out, contains('[8/9] Generating app shell (ZuraffaApp)...'));
        expect(out, contains('lib/main.dart'));
        expect(out, contains('lib/src/app/my_app.dart'));
        expect(out, contains('lib/src/routing/app_router.dart'));
      },
    );
  });
}
