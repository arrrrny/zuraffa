# Cycle Log: zfa setup ships a red day-zero baseline (issue #626)

Append only. Newest last. Every entry's `red` block is the evidence that the test
existed and failed before the implementation.

Bug workflow note: spec-kit's feature resolver (`check-prerequisites.sh`) errors
on this branch (no `.specify/feature.json`) — this is a bug triage fix, not a
feature, so `FEATURE_DIR` is the bug directory
`.specify/bugs/zfa-setup-red-day-zero-baseline/` and the audited criteria come
from `assessment.md` ("Tests to add or update") plus spec 041 FR-001/FR-006.

## Baseline

- suite: `dart test` (fast tier, chunked for the 9.9G disk) -> 2668 passed,
  0 failed, 1 skipped; `dart analyze` -> No issues found
- commit: `9319b13` (master head when the branch was cut)
- recorded: cycle 0, before any change on `fix/626-zfa-setup-red-day-zero-baseline`

## Cycle 1: FR-006 gate — fresh zfa setup -> flutter test exits 0

- test: `test/integration/day_zero_smoke_gate_test.dart::fresh zfa setup emits
  the app-name container and flutter test exits 0` (new, slow+integration tier)
- red (manual live repro, pre-test confirmation):
  `dart run bin/zfa.dart setup probe_626 --platforms=linux --no-git` then
  `flutter test` in the generated app
  -> exit 1, `00:00 +0 -1: Some tests failed.`,
  `Error when reading 'lib/app.dart': No such file or directory`,
  `Method not found: 'AppContainer'` — the day-zero red the issue reports.
- red (committed test, run before any source change):
  `dart test test/integration/day_zero_smoke_gate_test.dart --preset=integration`
  -> `00:29 +0 -1 ... Expected: true / Actual: <false> / zfa setup must emit
  lib/app.dart (the day-zero app module asserted by the smoke test)`
  (1 failed, 1 passed-empty: gate 2 failed separately)
- green: `zfa setup` now emits `lib/app.dart`
  (`AppModuleWriter`: `ZikZakTddContainer`, zfa-stamped, bootstrap DI) and the
  smoke test asserts the app-name-derived symbol (`SmokeTestWriter` renders
  `AppModuleWriter.containerSymbolFor(appName)`).
  `dart test test/integration/day_zero_smoke_gate_test.dart --preset=integration`
  -> `01:16 +2: All tests passed!` (both gates green; flutter test exit 0
  asserted inside each).

## Cycle 2: upgrade path — zfa app shell succeeds on a fresh setup and stays green

- test: `test/integration/day_zero_smoke_gate_test.dart::upgrade path: zfa app
  shell succeeds on a fresh setup and stays green` (new, slow+integration tier)
- red (committed test, run before any source change):
  `dart test test/integration/day_zero_smoke_gate_test.dart --preset=integration`
  -> `00:36 +0 -2 ... Expected: <0> / Actual: <1> / zfa app shell must succeed
  on a fresh setup via the bootstrap DI index. Output: ❌ Error:
  .../lib/src/di/index.dart does not declare setupDependencies(...).`
- green: setup emits the bootstrap barrels (`BootstrapDiIndexWriter` → empty
  `setupDependencies(GetIt getIt)`, `BootstrapRoutingIndexWriter` → empty
  `getAllRoutes()`) so the app-shell preflight passes day zero; the shell
  replaces the flutter-create Hello-World stub without `--force`
  (`AppShellBuilder.isFlutterCreateHelloWorldStub`). Same run as cycle 1:
  `01:16 +2: All tests passed!`, including the post-upgrade
  `flutter test` exit-0 assertion. Live corroboration: `zfa setup probe_626b`
  + `zfa app shell` -> `✅ App shell generated.`, `flutter test` exit 0,
  main.dart = `setupDependencies(GetIt.instance); runApp(const MyApp());`

## Cycle 3: refactor — reconciled Next Steps + coverage for the refactor artifact

- refactor: setup Next Steps now list `zfa app shell` (upgrade the day-zero app
  module with the generated DI + routes) and the smoke-test line names the
  app-name-derived container; `_emitTddBaseline` prints the app module +
  bootstrap barrels.
- test: `test/commands/setup_command_test.dart::dry-run previews the day-zero
  app module and app-shell next step` (added to an existing file)
- note: this assertion was added after the behavior existed (test-after);
  recorded as such in tdd/verification.md findings. The two assessment-required
  behaviors above were test-first (cycles 1-2).
- green: `dart test test/commands/setup_command_test.dart --preset=all`
  -> `00:00 +44: All tests passed!`

## Suite state after the loop

- fast tier (chunked, per-folder `dart test` with `/tmp/dart_test.kernel.*`
  cleanup between chunks — the whole-suite kernel compile peaks ~6.5G and does
  not fit the 9.9G disk): 2668+1+96(skeleton re-run) passed, 0 failed.
  The single earlier `test/plugins` chunk reported 22 failures, all
  `No space left on device` (environmental); re-run sub-chunked -> all green.
- `dart analyze` -> No issues found; `dart format .` -> 0 changed after
  formatting.
