# Plan: 1395-day-zero-module-deps

## Root cause

The day-zero app module (`lib/app.dart`) is emitted by TWO writer passes:

1. `zfa tdd init` / the #1528 entry preflight → `TddBaselineInit.ensure()`
   (`lib/src/plugins/tdd/services/baseline_init.dart`). Since issue #1349
   (PR #1461) this pass runs `PubspecAppDependenciesPatcher.ensure()` right
   after `AppModuleWriter` — idempotent, hand-edit preserving.
2. `zfa setup` → `SetupCommand._emitTddBaseline()`
   (`lib/src/commands/setup_command.dart`). This pass writes the SAME
   module (via `AppModuleWriter(isFlutter: true)`) but only self-healed the
   TESTING dev_dependencies (`PubspecDevDependenciesPatcher`) — the module's
   runtime deps were never declared by this pass. On the default scaffold
   the `DependencyWirer.standardSet` happens to wire `zuraffa_flutter`, which
   masked the catastrophic 3-error shape, but the pass itself violated the
   same-pass contract: `get_it` was never declared by ANY setup pass, and
   any consumer tree where the wirer does not cover the pair lands in the
   #1395 misfire state (undeclared-dep analyzer errors → the #942 build gate
   refuses the acceptance composition).

## Remediation design

Minimal, init-path-only-in-spirit fix (dependency declaration in the
day-zero writer pass; the generated module's imports and the #942 guard
semantics untouched):

- `PubspecAppDependenciesPatcher.ensure` gains a `dryRun` parameter
  mirroring `PubspecDevDependenciesPatcher.ensure` (report what WOULD be
  added, tolerate a missing pubspec, never touch disk) so setup's
  `--dry-run` preview stays side-effect free. The dry-run returns the same
  `'$pkg: $constraint'` entry shape as the real pass.
- `SetupCommand._emitTddBaseline` runs the SAME `ensure()` right after the
  `AppModuleWriter.write()` — the same pass as the module write, printing
  the same ✓/Would-add lines the dev-deps pass prints.

## Test plan (red → green)

| id | suite | what it pins |
| -- | ----- | ------------ |
| U-1395-a | test/commands/setup_1395_day_zero_app_deps_test.dart | `zfa setup --dry-run` previews the app-module runtime deps in the same pass as the `lib/app.dart` line |
| U-1395-b | test/cli/writers/tdd/pubspec_app_dependencies_patcher_1395_dryrun_test.dart | dry-run on a scaffolded-from-scratch project reports both deps, writes nothing |
| U-1395-c | same | dry-run on an existing pubspec reports ONLY the missing entries, byte-identical on disk |
| U-1395-d | same | additivity: an already-wired `zuraffa_flutter` gains ONLY `get_it`, under `dependencies:` |
| U-1395-e | same | re-run adds nothing (idempotent, cross-command) |
| I-1395-a | test/integration/day_zero_smoke_gate_test.dart | fresh `zfa setup`: both deps declared under `dependencies:`, `dart analyze lib` 0 errors, `zfa tdd init` re-run does not duplicate |

## Verification

- Red: U-1395-a observed failing pre-fix for the right reason (the preview
  lacked both deps). U-1395-b…e use the new `dryRun` seam — the
  compile-error red is the honest first red for a NEW seam (house
  convention, cf. #1664).
- Green: all unit suites + the integration gate; fresh-consumer runs of
  `zfa tdd init` (No issues found) and `zfa setup` (0 errors, `flutter test`
  green); `zfa tdd run` on a minimal feature → `result=complete` with
  0 pre-existing failures; `zfa build` passes the #942 gate
  ("dart analyze: no errors").

See `tdd/verification.md` for the full recorded run.
