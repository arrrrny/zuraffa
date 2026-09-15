**Template Version**: `zuraffa-1.0`

# Tasks: 1637-build-skip-content-hashing

## 1. Behavioural (TDD red → green first)

- [ ] **T001** (P1) `test/plugins/tdd/services/build_relevance_test.dart`
  — new group `refactorBuildSkipNote (issue #1637 config content
  hashing)`: the byte-identical-refresh scenario (AC-1/SC-001) —
  first gate call on a newer-but-unbaselined config runs and records
  the baseline; after a completed build (marker moved strictly newer)
  a byte-identical config refresh (same bytes, fresh mtime) SKIPS.
  [FR-001, FR-002, FR-004; SC-001] [behavior: A1]
- [ ] **T002** (P1) same file — the real-change scenario (AC-2/SC-002):
  trusted baseline, then a config file's CONTENT actually changes →
  the gate returns null (run) and re-records the baseline. Same test
  proves `pubspec.lock`, `.dart_tool/package_config.json`,
  `dart_test.yaml`, `analysis_options.yaml` ride one tier (AC-5,
  SC-005: identical-refresh skips for dart_test.yaml; real change in
  analysis_options.yaml runs). [FR-001, FR-007; SC-002, SC-005] [behavior: A2, A5]
- [ ] **T003** (P1) same file — the fail-safe scenarios (AC-3/AC-4,
  SC-003/SC-004): no baseline → run; corrupt baseline bytes → run;
  wrong-version baseline → run; baseline whose recorded marker mtime
  is NOT strictly older than the current marker → run even with
  matching digests. Every one of them still records a fresh baseline
  for the next cycle. [FR-005, FR-006; SC-003, SC-004] [behavior: A3, A4]
- [ ] **T004** (P1) same file — mechanism reuse (AC-3/FR-003, SC-007
  bridge): a baseline whose digests were derived from
  `BuildRelevance.fingerprint(projectRoot)` (the public mechanism, not
  the gate's private helper) is trusted and clears the config tier —
  proving fingerprint digests and baseline digests are the same
  currency; a baseline seeded with a wrong digest for one config file
  forces the run. [FR-003; SC-007] [behavior: U1, U3]
- [ ] **T005** (P2) same file — no-drift guards (AC-6, SC-006): the
  pre-#1637 shapes keep their verdicts with the fix in place (missing
  marker → run; no newer file → skip; newer annotated .dart → run;
  newer non-Dart → run; newer plain .dart → skip) and the skip path
  does not rewrite/invalidate the baseline (a third gate call still
  skips). [FR-005, FR-006; SC-006] [behavior: A6, U2, U5, U6]
- [ ] **T006** (P2) `test/plugins/tdd/services/refactor_passes_test.dart`
  — extend the existing issue-#1624 binding test: after a run-decision
  records a baseline and the marker moves (simulated completed build),
  the BOUND gate returns the skip note for a byte-identical config
  refresh — the registry-level proof that the pass is not spawned
  (SC-007). No registry, pass-spec, or build-command changes. [FR-008;
  SC-007] [behavior: A6]

## 2. Non-behavioural (implement to green)

- [ ] **T101** (P1) `lib/src/plugins/tdd/services/build_relevance.dart`
  — the fix: `configFingerprint` helper (fingerprint mechanism over
  `buildConfigFiles` only), baseline load/validate/record helpers
  (`.dart_tool/zfa/build_config_baseline.json`, version field,
  strictly-older marker validity), and the new config tier inside
  `refactorBuildSkipNote` (mtime pre-filter → digest fallback →
  fail-safe run + record). Every error fails toward RUN; the skip
  path never writes the baseline. [FR-001..FR-006] [behavior: U1-U5] [implementation]
- [ ] **T102** (P2) `lib/src/plugins/tdd/services/build_relevance.dart`
  — documentation: class-doc paragraph for #1637 (config tier content
  hashing, baseline validity semantics), `refactorBuildSkipNote`
  step-contract update, and the `refactorBuildSkippedNote` text
  gaining the #1637 clause so recorded evidence states the
  config-hash clearing honestly. [FR-001, FR-008]
- [ ] **T103** (P3) spec-kit artifacts — `specs/1637-build-skip-content-hashing/`
  (`spec.md`, `plan.md`, `tasks.md`, `tdd/test-list.md`,
  `tdd/cycle-log.md`, `tdd/verification.md`) committed with the code
  after each phase.
