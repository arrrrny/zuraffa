# Cycle Log: 1637-build-skip-content-hashing

Append only. Newest last. Every entry's `red` block is the evidence that the test
existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/services/build_relevance_test.dart test/plugins/tdd/services/refactor_passes_test.dart` → 34 passed, 0 failed
- commit: `aa5fe281`
- recorded: cycle 0, before any change
- note: scoped baseline (the two suites that own the gate's contract),
  per `.specify/memory/tdd-profile.md` feature-scope guidance.

## Cycle 1: A1 — byte-identical config refresh after a completed build skips

- test: `test/plugins/tdd/services/build_relevance_test.dart::refactorBuildSkipNote (issue #1637 config content hashing) > a byte-identical config refresh after a completed build skips the build` (new, +10 sibling tests in the same group, +1 registry-bound test in refactor_passes_test.dart)
- red: `dart test test/plugins/tdd/services/build_relevance_test.dart test/plugins/tdd/services/refactor_passes_test.dart`
  → 9 failed, 37 passed. The RED set (all for the right reason — the
  pre-fix gate has no baseline mechanism and forces RUN on any newer
  config file):
  - A1 byte-identical refresh skips → `Expected: true / Actual: <false> / the run decision records the config baseline` (the gate never records a baseline; the follow-up skip assertion is unreachable)
  - A2 real change re-records baseline → read of the (nonexistent)
    baseline file throws
  - A3 missing/corrupt/wrong-version records a fresh baseline →
    `existsSync` false (no recording)
  - A5 dart_test.yaml identical refresh skips → expected the skip note,
    got null
  - U1 fingerprint-derived digests trusted → expected the skip note,
    got null
  - U2 mixed-tree skip → expected the skip note, got null
  - U4 baseline is version-1 JSON → file absent
  - U5 skip path never rewrites → expected the skip note, got null
  - A6/T006 bound registry gate skips → expected the skip note, got null
  - GREEN by construction (fail-safe guards that could not be red
    pre-fix: the #1624 gate already runs on any newer config): A4
    untrusted-baseline validity, U3 one-wrong-digest runs, A5b real
    analysis_options change runs.
- green: T101 implementation — `configFingerprint` (fingerprint
  mechanism over `buildConfigFiles` only), baseline
  load/validate/record helpers, and the new config tier inside
  `refactorBuildSkipNote`. See cycle 2.

## Cycle 2: T101 green — the config tier clears byte-identical refreshes

- implementation: `lib/src/plugins/tdd/services/build_relevance.dart`
  — `configFingerprint` (FR-003), `_loadConfigBaseline` /
  `_recordConfigBaseline` (FR-004/FR-005/FR-006), and the new config
  tier inside `refactorBuildSkipNote` (FR-001/FR-002); doc contract
  rewritten (T102) and `refactorBuildSkippedNote` now states the
  config-hash clearing honestly.
- green: `dart test test/plugins/tdd/services/build_relevance_test.dart test/plugins/tdd/services/refactor_passes_test.dart`
  → 46 passed, 0 failed (34 baseline + 12 new: 9 reds turned green,
  3 fail-safe guards stayed green).
- refactor: none needed — the config tier is one guarded block plus
  two private helpers; the pre-filter walk and the non-config verdict
  loop are byte-identical to #1624's (FR-008).
- commit: (this commit)


