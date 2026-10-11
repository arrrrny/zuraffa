# Tasks: 1623-integration-timeout-budget

- **Spec ID**: 1623-integration-timeout-budget
- **Created**: 2026-09-15

Dependency order: T001 (budget-matrix tests + timeout-diagnostic pin, RED
evidence) → T002 (fix: cold-source budget + spawn wiring in the helper,
GREEN) → T003 (B9b override removal + README contract rewrite,
non-behavioral/config/docs) → T004 (verify + artifacts).

## T001: Red — budget matrix + timeout-diagnostic pin

- `test/helpers/zfa_test_timeout_scale_test.dart` — new group
  `cold source spawn budget`:
  - R1 (SC-3): `zfaColdSourceChildTimeout` == 240s × process scale and
    `greaterThanOrEqualTo(const Duration(seconds: 240))` (scale relaxes,
    never tightens)
  - R2 (SC-3): `resolveChildTimeout` — first source spawn
    (`sourceSpawn: true, coldBudgetAvailable: true, explicit: null`) →
    `zfaColdSourceChildTimeout` (NOT the 75s default)
  - R3 (SC-3): `resolveChildTimeout` — later source spawns
    (`coldBudgetAvailable: false`) and every compiled-binary spawn
    (`sourceSpawn: false`) → `zfaDefaultChildTimeout`
  - R4 (SC-3): `resolveChildTimeout` — an explicit caller timeout wins and
    is returned verbatim (never auto-scaled) on every path
- `test/cli/zfa_executable_test.dart` — U11 next to U6:
  - R5 (SC-2, regression pin for 06ecc54): a compile runner that fails
    with `TimeoutException` → `ZfaCompilationException` with exitCode −1,
    reason containing the budget language (`exceeded its` + `budget`) and
    the `ZFA_TEST_TIMEOUT_SCALE` remedy
- RED EVIDENCE: run both files against HEAD → R1–R4 fail to compile
  (`zfaColdSourceChildTimeout` / `resolveChildTimeout` not defined — the
  API does not exist yet); R5 passes by design (pin, recorded as such —
  NOT a fabricated red) → record `tdd/cycle-log.md`
- Tests: `test/helpers/zfa_test_timeout_scale_test.dart`,
  `test/cli/zfa_executable_test.dart`

## T002: Green — the helper budget

- `test/helpers/run_zfa_source.dart` ONLY:
  - `kZfaColdSourceBaseTimeout = Duration(seconds: 240)` with the full
    why-doc (84s measured cold JIT start, ~2.9× headroom, fits the 360s
    B9b / 480s B9 const ceilings at scale 1.0)
  - `zfaColdSourceChildTimeout` getter = `scaleDuration(kZfaColdSourceBaseTimeout)`
  - `resolveChildTimeout(...)` pure resolver with the documented matrix
  - `_zfaColdSourceBudgetSpent` isolate-global flag + wiring in
    `runZfaSource`: `sourceSpawn = ZfaExecutable.isDartScript(exe)`,
    budget through the resolver, mark spent when the cold budget is
    consumed
- GREEN: R1–R4 pass; R5 stays green; the pre-existing scale-matrix tests
  (75s/100s budgets) stay green
- Tests: `test/helpers/zfa_test_timeout_scale_test.dart`

## T003: Non-behavioral — budget debt removal + docs (config/docs)

- `test/package_sdk/plugin_scaffold_e2e_test.dart` B9b: remove the
  `timeout: const Duration(seconds: 240)` argument and replace the stale
  pre-policy comment with the current contract (helper budgets the spawn;
  `ZFA_TEST_TIMEOUT_SCALE` governs slow hosts). NO assertion/logic edits.
- `test/README.md`:
  - replace the obsolete "silently downgrades" sentence with the
    loud-failure contract (`ZfaCompilationException` → `StateError` in
    `setUpAll`, never a degraded suite)
  - add the 240s first-cold-source-spawn budget bullet (scale-stretched,
    spent after the first source spawn)
  - add a worked slow-CI-host example: job-env `ZFA_TEST_TIMEOUT_SCALE=2`
    + when to pair it with `--timeout xN` for fixed `dart_test.yaml` tag
    ceilings
- GREEN: R1–R5 stay green

## T004: Verify + artifacts

- `dart analyze` on every changed file — no new issues
- fast tier: `dart test test/helpers/zfa_test_timeout_scale_test.dart
  test/cli/zfa_executable_test.dart` — all green, count recorded
- integration: `dart test --preset=integration
  test/package_sdk/plugin_scaffold_e2e_test.dart -n B9b` — green WITHOUT
  the manual override (SC-1 end-to-end proof), elapsed recorded
- `dart format` — zero remaining diffs
- write `tdd/verification.md` from the REAL runs (verdicts, counts,
  elapsed, SC audit table) — never a stale copy
