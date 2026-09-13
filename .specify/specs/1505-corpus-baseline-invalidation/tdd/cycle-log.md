# Cycle Log: 1505-corpus-baseline-invalidation

Append-only. One entry per TDD cycle (spec 046 / TDD extension v1.1.2).

## Cycle: T001 (red)

- behavior: T001
- kind: red
- classification: assertionFailure
- criterion: US-1 / SC-1 (spec.md)
- test: `test/plugins/tdd/corpus_economics/baseline_cache_test.dart` — "T001: creating a file under test/ flips the fingerprint and read() misses"
- command: `dart test test/plugins/tdd/corpus_economics/baseline_cache_test.dart`
- exit: 1
- at: 2026-09-13T00:00:00Z
- output:
```
Expected: not '58c0f883d60820568278790bf110d96b94a401cb05a5b0d77640f2b199313fd1'
  Actual: '58c0f883d60820568278790bf110d96b94a401cb05a5b0d77640f2b199313fd1'
a test/ tree change MUST invalidate the corpus baseline
```
- reading: the fingerprint is IDENTICAL before/after creating
  `test/broken_test.dart` — the reported root cause reproduced at unit
  level (sha256 covers pubspec + lock + suite template only).

## Cycle: T002 (red)

- behavior: T002
- kind: red
- classification: assertionFailure
- criterion: US-2 / SC-1
- test: same file — "T002: a modified lib/ source flips the fingerprint"
- command: `dart test test/plugins/tdd/corpus_economics/baseline_cache_test.dart`
- exit: 1
- at: 2026-09-13T00:00:00Z
- output:
```
Expected: not '<sha256 F1>'
  Actual: '<sha256 F1>'
a lib/ source change can change test outcomes
```

## Cycle: T003 (red)

- behavior: T003
- kind: red
- classification: assertionFailure
- criterion: US-3 / SC-2
- test: same file — "T003: .zfa/ memory/manifest state participates in the fingerprint"
- command: `dart test test/plugins/tdd/corpus_economics/baseline_cache_test.dart`
- exit: 1
- at: 2026-09-13T00:00:00Z
- output:
```
Expected: not '<sha256 F1>'
  Actual: '<sha256 F1>'
the corpus manifest is run-stable declared project state
```

## Cycle: driver repro (red)

- behavior: T004 (driver)
- kind: red
- classification: assertionFailure
- criterion: US-1 / SC-4 (the #1505 repro, end-to-end)
- test: same file — "#1505 repro: a test-file fix between runs invalidates the corpus cache"
- command: `dart test test/plugins/tdd/corpus_economics/baseline_cache_test.dart`
- exit: 1
- at: 2026-09-13T00:00:00Z
- output (abridged):
```
Expected: <2>
  Actual: <1>
  the second feature must not re-run the suite   ← economics spy count held at 1
corpus-wide reuse (fingerprint match; spec 069 T004) — …   ← stale reuse line present
```
- reading: with the pre-fix fingerprint the driver reuses the garbage
  snapshot and never re-runs the suite — the exact reported failure.

## RED summary (first full run)

- command: `dart test test/plugins/tdd/corpus_economics/baseline_cache_test.dart`
- result: `+12 -4: Some tests failed.`
- red set (exactly as planned): T001, T002, T003, #1505 repro.
- green-before guards (regression pins, not red-cycle subjects): T006,
  T007, T008u, #1505 economics guard, R1–R8 (8 pre-existing tests).
