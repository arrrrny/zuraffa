# Tasks: 894-corpus-economics

- **Spec ID**: 894-corpus-economics
- **Created**: 2026-09-03

## T001: Incremental verification
- Implement pass-registry change tracking
- Scope refactor re-proof to changed files only
- Full-suite proof on feature completion + nightly
- Tests: `incremental_verify_test.dart`

## T002: Batched gen/verify-red
- Implement `zfa tdd gen --all` for batch generation
- Reduce per-behavior `dart test` spawns
- Tests: `batch_gen_test.dart`

## T003: Sharding + concurrency
- Implement corpus sharder for distributing features
- Add budget telemetry to JSON verdicts (wall-clock, suite secs, mutants)
- Tests: `corpus_sharder_test.dart`, `budget_telemetry_test.dart`

## T004: Baseline cache reuse
- Extend #741 cache machinery corpus-wide
- Implement cache reuse across features with correct invalidation
- Tests: `baseline_cache_test.dart`

## T005: Acceptance verification
- Measure 120-spec corpus full verify on Intel Mac class
- Verify ≤ 30 min full verify
- Verify ≤ 10 min per-PR sharded lane
- Tests: `corpus_economics_integration_test.dart` (smoke on subset)

## T006: End-to-end verification
- Run `/speckit.tdd.verify` against the full spec
- Generate `tdd/verification.md` from real run
- Commit and open PR
## T007: Measure the acceptance targets on a real corpus (remediation from /speckit.tdd.verify)
- Run the full corpus lane on a real >=120-spec corpus on Intel-Mac-class hardware
- Gate on the budget-telemetry verdict's wall_clock_ms (<= 30 min full lane, <= 10 min per shard lane)
- Replace the projected acceptance numbers in specs/069-corpus-economics/tdd/verification.md with the measured ones
