**Template Version**: `zuraffa-1.0`

# Tasks: 1587-make-skip-or-batch-build

## 1. Behavioural (TDD red → green first)

- [ ] **T001** (P1) `test/plugins/tdd/services/build_relevance_test.dart`
  — pure gate decision unit tests: empty changed set → skip; plain
  un-annotated `.dart` writes → skip; `@Zorphy`/`@JsonSerializable`/
  `@HiveType`/`@Route` annotated write → no skip; config file change →
  no skip; deletion → no skip; non-dart write → no skip. [FR-001,
  SC-001..SC-003]
- [ ] **T002** (P1) `test/plugins/tdd/make_command_1587_build_skip_test.dart`
  — through `zfa tdd make`: generation writes nothing → `build` absent
  from fake-zfa argv log, skip note printed, green evidence carries the
  synthetic step with exit 0 + skip note, outcome green exit 0.
  [FR-001/FR-002, SC-001]
- [ ] **T003** (P1) same file — generation rewrites the subject under
  `lib/` → `build` present in argv log (unchanged), #737/#942 tolerance
  paths intact. [FR-003, SC-002]
- [ ] **T004** (P1) same file — generation writes an annotated
  (`@Zorphy`) dart file → `build` present. [FR-001, SC-003]
- [ ] **T005** (P2) same file — hashless-certified-red make still runs
  the live drift check (dedup fails open) and the live build. [FR-005]
- [ ] **T006** (P1) `test/plugins/tdd/make_command_1587_dedup_test.dart`
  — certified red WITH matching subject-hash as the LAST entry → make
  precondition runs zero target-test subprocesses (observable: dedup
  note printed; generation still runs; green evidence live). [FR-004,
  SC-004]
- [ ] **T007** (P1) same file — subject hash differs (hand-implemented
  subject) → live drift check runs (fail-open note absent). [FR-005,
  SC-005]
- [ ] **T008** (P2) same file — green entry after the last red → live
  drift check runs; already-green skip transition outcome=skipped
  unchanged. [FR-005, scenario 5]

## 2. Non-behavioural (implement to green)

- [ ] **T101** (P1) `lib/src/plugins/tdd/services/build_relevance.dart`
  — fingerprint + `canSkipTerminalBuild` (FR-001).
- [ ] **T102** (P1) `lib/src/plugins/tdd/models/generation_plan.dart` —
  `GenerationStep.buildSkipped` optional field (default false) (FR-002).
- [ ] **T103** (P1) `lib/src/plugins/tdd/services/pipeline_runner.dart` —
  `runPlan(skipUnchangedBuild = false)`: fingerprint before step 0,
  evaluate before an exactly-`['build']` step, synthetic captured step
  on skip (FR-001/FR-002/FR-008).
- [ ] **T104** (P1) `lib/src/plugins/tdd/models/cycle_entry.dart` —
  render `note:` line for skipped build steps in the generation block
  (FR-002).
- [ ] **T105** (P1) `lib/src/plugins/tdd/commands/make_command.dart` —
  opt into `skipUnchangedBuild: true`; `_driftRunDedupCertificate`
  helper guards the live drift re-run; decision notes printed (FR-004/
  FR-005/FR-007).
- [ ] **T106** (P2) docs touch: the make command's header comment block
  records the #1587 scheduling contract (FR-007).

## 3. Verification

- [ ] **T201** full targeted suites green (both new files + existing
  make/pipeline suites), `dart analyze` zero new findings vs baseline,
  `dart format` clean. [SC-006]
