// SPEC 1395 — the day-zero writer that emits `lib/app.dart` must declare
// the module's runtime deps in the SAME pass.
//
// `zfa setup`'s Part-1 TDD baseline emission (`_emitTddBaseline`) writes
// the day-zero app module (`lib/app.dart`, via AppModuleWriter) whose
// generated source imports `package:zuraffa_flutter/zuraffa_flutter.dart`
// and uses `GetIt` — but setup only self-healed the TESTING
// dev_dependencies. The runtime deps the generated module requires
// (`zuraffa_flutter`, `get_it`) were never declared by THAT pass, so a
// fresh consumer tree analyzed red out of the box (the observed #1395
// misfire: 2 analyzer errors on `GetIt` + the
// `depend_on_referenced_packages` info on `zuraffa_flutter`), and the
// acceptance composition (`zfa build`, phase 2 of A2) hit the #942 build
// gate and refused — the engine lane could never complete its acceptance
// half.
//
// `zfa tdd init` already self-heals the same pair in its own baseline
// sequence (issue #1349, `TddBaselineInit` → `PubspecAppDependenciesPatcher`).
// The #1395 fix wires the SAME idempotent patcher into the setup day-zero
// pass, right after the module write.
//
// This file pins the COMMAND-level contract: `zfa setup --dry-run`
// previews the app-module deps patch in the day-zero baseline output,
// in the same pass as the `lib/app.dart` line. The writer-level
// dry-run/additivity/idempotency contract is pinned in
// `test/cli/writers/tdd/pubspec_app_dependencies_patcher_1395_dryrun_test.dart`,
// and the end-to-end fresh-consumer gate in
// `test/integration/day_zero_smoke_gate_test.dart`.
library;

import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/setup_command.dart';

void main() {
  group('spec 1395: the setup day-zero pass declares the app-module deps', () {
    test('dry-run previews the app-module runtime deps in the same pass as '
        'lib/app.dart', () async {
      final runner = CommandRunner('zfa', 'test')..addCommand(SetupCommand());
      final prints = <String>[];
      await runZoned(
        () => runner.run(['setup', 'demo_app', '--dry-run', '--flutter']),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, message) => prints.add(message),
        ),
      );
      final out = prints.join('\n');

      // The preview reports the module write ...
      expect(
        out,
        contains('lib/app.dart'),
        reason: 'the day-zero baseline preview must include the app module',
      );
      // ... and, in the SAME pass, the runtime deps the module
      // requires (the #1395 gap: only the dev_dependencies were
      // previewed before).
      expect(
        out,
        contains('zuraffa_flutter: ^6.0.0'),
        reason:
            'the generated lib/app.dart imports '
            'package:zuraffa_flutter/zuraffa_flutter.dart — the day-zero '
            'pass must declare it (spec 1395)',
      );
      expect(
        out,
        contains('get_it: ^9.2.1'),
        reason:
            'the generated app module exposes `final GetIt di = '
            'GetIt.instance` — the day-zero pass must declare get_it '
            '(spec 1395)',
      );
      expect(
        out,
        contains('pubspec.yaml dependencies (app module)'),
        reason:
            'the deps patch rides the app-module pass, distinct from the '
            'dev_dependencies line',
      );
    });
  });
}
