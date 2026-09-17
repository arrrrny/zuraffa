# TDD test list — Spec 1395 the day-zero app module declares its deps (fresh consumer analyzes clean after init)

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1395-a | test/commands/setup_1395_day_zero_app_deps_test.dart | unit | `zfa setup --dry-run --flutter` previews the app-module runtime deps (`zuraffa_flutter: ^6.0.0`, `get_it: ^9.2.1`) in the SAME pass as the `lib/app.dart` line — the day-zero pass declares what the module imports | spec FR-001 | RED → GREEN |
| U-1395-b | test/cli/writers/tdd/pubspec_app_dependencies_patcher_1395_dryrun_test.dart | unit | dry-run on a scaffolded-from-scratch project reports BOTH deps and writes nothing (missing pubspec tolerated, disk untouched) | spec FR-001 (preview half) | RED (new-seam compile red) → GREEN |
| U-1395-c | test/cli/writers/tdd/pubspec_app_dependencies_patcher_1395_dryrun_test.dart | unit | dry-run on an existing pubspec reports ONLY the missing entries and leaves the file byte-identical | spec FR-002 (skip-if-declared) | RED (new-seam compile red) → GREEN |
| U-1395-d | test/cli/writers/tdd/pubspec_app_dependencies_patcher_1395_dryrun_test.dart | unit | additivity: a wirer-declared `zuraffa_flutter` gains ONLY the missing `get_it`, under `dependencies:` (runtime), never duplicated | spec FR-002 | RED (new-seam compile red) → GREEN |
| U-1395-e | test/cli/writers/tdd/pubspec_app_dependencies_patcher_1395_dryrun_test.dart | unit | re-running the pass adds nothing — idempotent across commands (setup then `zfa tdd init`'s #1349 self-heal) | spec FR-002 | RED (new-seam compile red) → GREEN |
| I-1395-a | test/integration/day_zero_smoke_gate_test.dart | integration | fresh `zfa setup`: both deps declared under `dependencies:`, `dart analyze lib` reports 0 errors (the #942 gate severity contract), `zfa tdd init` re-run does not duplicate | spec AC-1 | GREEN (manual session run recorded in verification.md) |

Guard pins (pre-existing, unchanged and green against the fix):

| id | suite | description |
| -- | ----- | ----------- |
| #1349 | test/cli/writers/tdd/bug_1349_init_flutter_app_deps_test.dart | the `zfa tdd init` self-heal contract this fix reuses — init adds the pair under `dependencies:`, idempotent, hand-edit preserving, pure-Dart untouched, malformed pubspecs fail loudly |
| #1349 writer | test/cli/writers/tdd/bug_1349_init_flutter_app_deps_test.dart (writer-level rows) | empty-inline expansion + non-map refusal + non-empty inline flow refusal |
| baseline sinks | test/plugins/tdd/services/baseline_init_sinks_test.dart | the #1528 shared writer sequence's sink contract — untouched |
| #1653 | test/plugins/tdd/bug_1653_init_opt_in_and_preresolve_test.dart | mutation opt-in + pre-resolve firing only when deps were newly injected — untouched |
| #626 | test/commands/setup_command_test.dart + test/cli/writers/tdd/app_module_writer_test.dart | day-zero module writers, dry-run preview shape — extended, not changed |
| dev-deps patcher | test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart | the dev-deps self-heal this fix's dry-run contract mirrors — untouched |

## Red evidence (pre-fix, this session)

- U-1395-a (stash of `setup_command.dart` + patcher, then):
  `dart test test/commands/setup_1395_day_zero_app_deps_test.dart`
  → `00:00 +0 -1: Some tests failed.`
  `Which: does not contain 'zuraffa_flutter: ^6.0.0'` — the day-zero
  baseline preview names `lib/app.dart` but declares none of the module's
  runtime deps. Exactly the #1395 gap.
- U-1395-b…e: the `dryRun` parameter did not exist pre-fix — the file fails
  at load. The compile-error red is the honest first red for a NEW seam
  (house convention, recorded for #1664 in this same directory).
- Manual red (the misfire shape, `zfa setup` on a fresh consumer pre-fix):
  step 6 wrote `lib/app.dart` while the ONLY pubspec pass added
  `coverage: ^1.15.1` to dev_dependencies — `get_it` declared by NO pass;
  the same-pass contract violated.

## Green evidence (post-fix, this session)

- `dart test test/commands/setup_1395_day_zero_app_deps_test.dart
  test/cli/writers/tdd/pubspec_app_dependencies_patcher_1395_dryrun_test.dart`
  → `00:00 +5: All tests passed!`
- Neighboring regression suites (writers + setup + baseline-init):
  `00:22 +72: All tests passed!`
- Manual end-to-end on a fresh consumer: `zfa setup` step 6 now prints
  `✓ pubspec.yaml dependencies (app module: added: get_it: ^9.2.1)`
  (additive — the wirer had already declared `zuraffa_flutter`),
  `dart analyze lib` → 0 errors, `flutter test` → all green.

Full transcript: `tdd/verification.md`.
