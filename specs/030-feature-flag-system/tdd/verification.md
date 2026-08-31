# Verification: Feature-Flag System — enable/disable zuraffa features per build

**Feature**: `030-feature-flag-system` | **Audited**: 2026-08-31 | **Auditor**: the implementing session (cold-context audit per `/speckit.tdd.verify`)

**Verdict: VERIFIED** — test-first evidence is real, all behaviors trace to
the spec, the loop closed green, and deliberate-mutant sampling killed all
sampled mutants.

## 1. Test-first audit

Every implementation cycle's `red` block in `tdd/cycle-log.md` predates its
`green` block, and the red evidence is real:

- Cycle 1 records the observed red for the ENTIRE new surface:
  `dart test test/feature_flags/` failed with "Cannot run `zfa make` for
  \"list\"" (the pre-feature scaffold dispatch swallowing `zfa feature
  list`) and "Error: Error when reading 'lib/src/feature_flags/
  feature_flag.dart': No such file or directory" / "Method not found:
  'emitRegistry'" / "Type 'ResolvedFeatureSet' not found" — the module did
  not exist when the tests were written. This is the canonical red for a
  new module: tests first, then the API they demand.
- Cycles 2-7 each implement exactly what a red test demanded and record
  the green. No implementation file was written before its test file
  existed in the same session (git history is a single feature commit per
  repo convention; the cycle log is the per-cycle evidence record).

## 2. Traceability audit

- 23 acceptance behaviors (A1-A23) — one per acceptance scenario in
  `spec.md` (US1: A1-A4, US2: A5-A8, US3: A9-A12, US4: A13-A17, US5:
  A18-A20, US6: A21-A23). All DONE, all traced.
- 10 unit behaviors (U1-U10) — one per functional requirement FR-001…
  FR-010 (+ split coverage for FR-004 across U6/U7). All DONE, all traced.
- Every `traces` value resolves to a US.AC or FR id in `spec.md`.
- SC-001..SC-004 coverage: SC-001 (disabled → zero references) via
  A6/U6/U7 (make-skip + route-filter, grep-verified in emitted router);
  SC-002 (<2s CLI) by construction — one JSON read + table print, the CLI
  tests complete in well under a second; SC-003 (O(1) lookup) — static
  const set membership in the emitted registry's runtime; SC-004 (flavor
  diff) via A7 subprocess e2e asserting distinct registries/routers per
  flavor.

## 3. Suite evidence (this session, real runs)

| Command | Result |
| --- | --- |
| `dart test test/feature_flags/` | **62 passed, 0 failed** (3 consecutive runs) |
| `dart analyze` | **No issues found!** |
| `dart format .` | Formatted 1361 files, **0 changed** |
| `tools/run_tests_chunked.sh` | **1369 passed, 0 failed** |

Pre-existing (NOT introduced by this feature, flagged per protocol): the
chunked runner exits non-zero on 3 chunks — `test/benchmark`,
`test/core/dependencies`, `test/integration` — because every test file in
them is tagged `slow`/`benchmark`/`integration`, which the runner
excludes, so `dart test` prints "No tests ran." and exits 1. Reproduced at
the pre-feature baseline (cycle-log Baseline); zero actual test failures.

## 4. Mutation sampling (deliberate mutants; no mutation tool wired per tdd-profile)

| # | Mutant | Test that must catch it | Result |
| --- | --- | --- | --- |
| M1 | Remove the flavor-override unknown-feature `throw` in `feature_flag_config.dart` | `feature_flag_config_test.dart::A4` | **KILLED** — test failed: expected FeatureConfigException, got none |
| M2 | Neuter `_disabledFeatureSkipReason` (always return null) in `make_command.dart` | `make_skip_test.dart::A6` | **KILLED** — disabled slice generated a file (fileCount 2 ≠ 1) |
| M3 | Membership gate `return tier != null` (drop tier equality) in `feature_flag_provider.dart` | `runtime_provider_test.dart::A13` | **KILLED** — free tier wrongly enabled |
| M4 | Invert the route-filter predicate (`return owned`) in `route_build_stage.dart` | `route_filter_test.dart` | **KILLED** — 2 tests red (disabled route kept, enabled dropped) |

All mutants were applied to the real source, observed red, and reverted;
post-revert `dart analyze` clean + 62/62 green re-confirmed.

## 5. Honest deviations (also in cycle-log)

1. **In-process CLI tests converted to subprocess runs.** Assertions on
   the dart:io `exitCode` global race across concurrently-running test
   isolates (it is process-global). Tests now follow the repo's race-free
   pattern (`runZfaSource` + explicit `workingDirectory`); real exit codes
   are asserted in the subprocess e2e (`build_flavor_filter_test.dart`).
2. **`runCapturing` captures zone `print()`, not `stdout.writeln`.**
   `FeatureFlagCli` was switched to `print()` so CLI output is capturable
   in-process and identical in real runs.
3. **A18's assertion form**: the emitted registry embeds the variant gate
   as its spec string `'variant:a|b'` (both variants declared), not as two
   separate quoted literals.
4. **tasks.md T005 partial deviation**: `zfa_config.dart` was still
   extended (rawFeatures/rawFlavors round-trip) but as a clobber-protection
   measure — the features/flavors sections are preserved verbatim across
   `ZfaConfig.save()` cycles; parsing/validation lives solely in
   `FeatureFlagConfig`.

## 6. Edge cases from the spec — resolved positions

- Feature enabled but its code absent: generation proceeds per config (a
  flag is a declaration, not a file check); make's existing entity-exists
  guard still fires for enabled slices (#496 behavior preserved).
- Unknown gate type (`tenant:xyz`): rejected at parse with feature+gate
  named (U1, tested).
- Conflicting flavor states: last override wins per feature, validated
  against declared features (U2, tested).
- Toggled after generation: next `zfa build` regenerates from config;
  staleness detection remains the existing build cache's concern (out of
  scope per plan.md).
- Membership provider unavailable: gate fails CLOSED (documented design
  decision in plan.md — entitlement checks must not fail open); the
  whole-feature PROVIDER failing falls back to the static default
  (US6.AC3, FR-010).
