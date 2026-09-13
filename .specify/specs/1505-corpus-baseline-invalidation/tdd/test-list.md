# Test List: 1505-corpus-baseline-invalidation

- **Feature**: 1505-corpus-baseline-invalidation
- **Spec**: `.specify/specs/1505-corpus-baseline-invalidation/spec.md`
- **Test home**: `test/plugins/tdd/corpus_economics/baseline_cache_test.dart`
  (unit group + driver group, TddFixture conventions)

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| T001 | a created test/ file flips the fingerprint and read() misses | US-1 / SC-1 | PENDING |
| T002 | a modified lib/ file flips the fingerprint | US-2 / SC-1 | PENDING |
| T003 | .zfa memory/manifest state changes flip the fingerprint | US-3 / SC-2 | PENDING |
| T006 | mtime-only touch does NOT flip the fingerprint | US-4 / SC-1 SC-3 | PENDING |
| T007 | run-mutated .zfa state (progress/lock/receipts/cache file) does NOT flip the fingerprint | US-4 / SC-3 | PENDING |
| T008u | fingerprint is stable across two computations with no changes (determinism) | US-4 / SC-3 | PENDING |

## Driver loop: end-to-end run behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| T004 | after a test-file fix, the second feature run re-runs the live suite (no corpus-wide reuse) — the #1505 repro | US-1 / SC-4 | PENDING |
| T008 | with no outcome-relevant change, the second feature run still reuses the corpus baseline (zero extra suite spawns) | US-4 / SC-4 | PENDING (may resolve green-by-design; see tasks.md T008) |

## Existing pinned behaviors (must stay green — regression guard)

| id | behavior | traces | where |
| -- | -------- | ------ | ----- |
| R1 | write()/read() round-trip on matching fingerprint | spec 069 T004 | baseline_cache_test.dart unit group |
| R2 | pubspec change flips fingerprint; read() misses | issue #916 | baseline_cache_test.dart unit group |
| R3 | missing/corrupt cache files → null | #741 stance | baseline_cache_test.dart unit group |
| R4 | no pubspec + no lock → null fingerprint | spec 069 | baseline_cache_test.dart unit group |
| R5 | second feature run reuses corpus baseline (economics) | spec 069 T004 | baseline_cache_test.dart driver group |
| R6 | pubspec change between runs invalidates; cache rewritten | issue #916 | baseline_cache_test.dart driver group |
| R7 | legacy profile command change must not reuse | #1374 family | baseline_cache_test.dart driver group |
| R8 | corrupt corpus cache → safe failure live run | #741 stance | baseline_cache_test.dart driver group |

## Cycle contract

- T001–T004, T006, T007: MUST be recorded RED (run + transcript in
  tdd/cycle-log.md) before the implementation lands.
- T008/T008u: record the first observed state honestly; if green at first
  run post-implementation, classify `green-by-design` with evidence (the
  allow-list is the design), never claim a fabricated red.
- R1–R8: regression set re-run at verification (tdd/verification.md).
