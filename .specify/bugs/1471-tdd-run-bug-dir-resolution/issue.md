## Summary
`zfa tdd run` (and `run-engine` / `run-skin` / `doctor` / `verify`) cannot operate
on the bug directory the speckit bug extension pins in `.specify/feature.json`.
`tdd plan` can (issue #1182), so the documented bug-workflow TDD loop
(`bug.fix` → `tdd.plan` → `tdd.run` → `tdd.verify`) stops at the run step with
exit 2. Every `/skill:speckit-bug-fix` with `tdd_enabled: true` on this repo is
blocked by it.

## Already tracked
This assessment was produced from an existing issue — **no new issue was filed**
(that would duplicate it).

- **Issue**: #1471 — *zfa tdd run rejects bug directories — bug-workflow TDD loop
  (bug.fix with tdd_enabled) cannot run*
- **URL**: https://github.com/arrrrny/zuraffa/issues/1471
- **State**: OPEN — labels `bug`, `tdd`, opened 2026-09-10 by `arrrrny`
- **Assessment**: `.specify/bugs/1471-tdd-run-bug-dir-resolution/assessment.md`

## Root cause (confirmed against the tree)
`TddFeaturePaths.resolve` (`lib/src/plugins/tdd/services/feature_path_resolver.dart`)
already supports plain name / `specs/<name>` / `.specify/bugs/<slug>` / absolute
paths, but `plan_command.dart:160` is its only caller. The runner family still
carries the pre-#1182 `specs/<feature>` assumption in four layers:

1. per-command validators — `validateFeatureSegment` (`run_driver_core.dart:2490`)
   rejects any `/`, producing the reported `❌ invalid feature … not a path` and
   exit 2 (`exit_protocol.dart:48`, `cli_runner.dart:399`);
2. per-command dir joins — `run_command.dart:195, 307, 329, 390, 438, 472, 479`,
   `run_engine_command.dart:192, 214, 245`, `run_skin_command.dart:187`,
   `doctor_command.dart:127`, `verify_command.dart:168`;
3. `RunDriverCore.drive` joins `specs/<feature>` itself
   (`run_driver_core.dart:256`, plus `:1298`, `:1433`, `:2380`) — fixing
   `run_command.dart` alone is not enough;
4. `_handStepViolationFor`'s project-root walk (`run_driver_core.dart:2104-2112`)
   keys on a parent literally named `specs`, so it mis-roots `.specify/bugs/<slug>`.

Additionally, **no** TDD command reads `.specify/feature.json` — the pin is
consumed only by other plugins (`bone_command.dart:101`,
`simulate_command.dart:395-422`, `certify_mock_capability.dart:251`,
`dependency_declaration_reader.dart:108`, `engine_receipt_writer.dart:298`). So
the issue's "honor the pin" expectation is new capability, not a regression.

## Suggested fix
Extract nothing new — finish the #1182 migration: add `feature_directory` pin
support to `TddFeaturePaths`, route the positional reference of run /
run-engine / run-skin / doctor / verify through it, pass the resolved
`featureDir` into `RunDriverCore.drive` (and its transaction / cycle-log /
lane-receipt sites), and fix the project-root derivation at
`run_driver_core.dart:2104`. Plain-name resolution must stay byte-identical.

## Environment
macOS, pure-Dart package, zfa v6.x working tree. Found while running bug-whole
for issue #1467 (slug `cycle-log-phantom-sections`,
branch `fix/cycle-log-phantom-sections`).
