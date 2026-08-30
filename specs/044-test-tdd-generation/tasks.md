# Tasks: 044 — Behavior-aware test generation and trustworthy mutation evidence

**Input**: Design documents from `specs/044-test-tdd-generation/`

**Organization**: Tasks grouped by user story. Part 1 (US1 — `gen`) is
MVP-first because `verify` cannot derive mutation scope from behavior
artifacts until `gen` has produced and registered them.

## Phase 1: Models (foundation)

- [ ] T001 Create `lib/src/plugins/tdd/models/ownership.dart`
      (`enum Ownership { created, reused, planned }`)
- [ ] T002 Create `lib/src/plugins/tdd/models/artifact_record.dart`
      (behavior id + test path + subject path + runnable test name +
      ownership + created_at)
- [ ] T003 Create `lib/src/plugins/tdd/models/mutation_outcome.dart`
      (`enum MutationOutcome { killed, survived, timedOut,
      notAssessed }` + `MutationGateDecision { pass, failSurvived,
      failTimeout, preflightRed, notAssessed }`)
- [ ] T004 [P] Unit tests for all three models
- [ ] T005 `dart analyze` clean

## Phase 2: Behavior-test writer (FR-001, 010)

- [ ] T006 Create `lib/src/plugins/tdd/services/behavior_test_writer.dart`
- [ ] T007 [P] `behavior_test_writer_test.dart` — writes a runnable
      test whose first execution fails with an assertion failure (not
      skipped, not pending, not placeholder, not compile error)
- [ ] T008 The generated test asserts the behavior's `description`,
      not a placeholder `expect(true, isFalse)`
- [ ] T009 The test carries the behavior id + source criterion in its
      group name and doc comment (consumed by the report later)

## Phase 3: Subject writer (FR-001, 004, 011)

- [ ] T010 Create `lib/src/plugins/tdd/services/subject_writer.dart`
- [ ] T011 [P] `subject_writer_test.dart` — writes a compilable
      subject for `unit` classification
- [ ] T012 [P] `subject_writer_test.dart` — writes a compilable
      subject for `acceptance` classification WITHOUT requiring a
      pre-existing entity/use case/repository
- [ ] T013 The generated subject passes `dart analyze` with zero
      errors (warnings OK for unused-element lints)

## Phase 4: Artifact registry (FR-005, 006, 007, 008)

- [ ] T014 Create `lib/src/plugins/tdd/services/artifact_registry.dart`
- [ ] T015 [P] `artifact_registry_test.dart` — appends a record on
      first `gen`, returns `reused` on a matching repeat (idempotent)
- [ ] T016 [P] `artifact_registry_test.dart` — refuses to overwrite a
      file that exists on disk but has no recorded ownership
      (FR-008)
- [ ] T017 [P] `artifact_registry_test.dart` — `--dry-run` writes no
      file and no registry entry (FR-009)

## Phase 5: User Story 1 — `zfa tdd gen <behavior-id>` (P1) 🎯 MVP

- [ ] T018 [P] `gen_command_test.dart` — happy path: produces
      exactly one test + one subject + structured result line
      (FR-001, 005)
- [ ] T019 [P] `gen_command_test.dart` — honest red: the generated
      test, on first execution, fails with assertion failure
      (FR-010)
- [ ] T020 [P] `gen_command_test.dart` — unknown id exits non-zero
      before any file is written (FR-002)
- [ ] T021 [P] `gen_command_test.dart` — missing required fields
      exits non-zero before any file is written (FR-002)
- [ ] T022 [P] `gen_command_test.dart` — acceptance classification
      works without pre-existing entity/use case/repository
      (FR-003, 004)
- [ ] T023 Implement `gen_command.dart` (rewritten from the
      misfire-stop stub)
- [ ] T024 End-to-end: invoke `dart test <generated-test-path>
      --plain-name "<test-name>"` and assert exit code non-zero and
      failure class is assertion

## Phase 6: User Story 2 — idempotency + ownership conflict + dry-run (P1)

- [ ] T025 [P] `gen_command_test.dart` — idempotent repeat: zero
      duplicate files; result reports `Ownership.reused` (FR-006)
- [ ] T026 [P] `gen_command_test.dart` — ownership conflict: file
      exists on disk without a registry entry → exit non-zero, file
      byte-for-byte unchanged (sha256 verified) (FR-008)
- [ ] T027 [P] `gen_command_test.dart` — `--dry-run` plans without
      writing (FR-009)

## Phase 7: Mutation scope + auditor + source restorer (FR-012..021)

- [ ] T028 Create `lib/src/plugins/tdd/services/mutation_scope.dart`
- [ ] T029 [P] `mutation_scope_test.dart` — derives scope from
      `artifacts.json` (FR-012)
- [ ] T030 [P] `mutation_scope_test.dart` — no registered artifacts
      → `NOT_ASSESSED — no behavior artifacts registered` (FR-012)
- [ ] T031 Create `lib/src/plugins/tdd/services/source_restorer.dart`
- [ ] T032 [P] `source_restorer_test.dart` — captures sha256
      pre-audit, restores post-audit, verifies match (FR-021)
- [ ] T033 [P] `source_restorer_test.dart` — restoration succeeds
      even on simulated interrupt (restoration loop uses `try/finally`)
- [ ] T034 Create `lib/src/plugins/tdd/services/mutation_auditor.dart`
- [ ] T035 [P] `mutation_auditor_test.dart` — green-suite preflight
      runs FIRST; if red → `PREFLIGHT_RED`, no mutation performed
      (FR-013)
- [ ] T036 [P] `mutation_auditor_test.dart` — tool unavailable →
      `NOT_ASSESSED — mutation tool unavailable` (FR-015)
- [ ] T037 [P] `mutation_auditor_test.dart` — empty/incomplete/
      unparseable report → `NOT_ASSESSED — <reason>` (FR-016)
- [ ] T038 [P] `mutation_auditor_test.dart` — killed/survived/
      timed-out recorded as three separate buckets (FR-014)
- [ ] T039 [P] `mutation_auditor_test.dart` — strict policy:
      ANY survived or timed-out → FAIL gate (FR-017)
- [ ] T040 [P] `mutation_auditor_test.dart` — report traces outcome
      to behavior id + source criterion (FR-018)
- [ ] T041 [P] `mutation_auditor_test.dart` — never edits a test to
      fake a pass (FR-022) — covered by reading-only test of the
      auditor's source: any write to test files throws.
- [ ] T042 [P] `mutation_auditor_test.dart` — source restoration
      verified by sha256 after audit (FR-021)

## Phase 8: User Story 3 — `zfa tdd verify --feature <feature>` (P1)

- [ ] T043 Rewrite `verify_command.dart` to delegate to
      `MutationAuditor` (was: directly invoked `MutationVerifier`)
- [ ] T044 [P] `verify_command_test.dart` — happy path: green
      preflight + mutation run + `verification.md` written with gate
      decision `PASS` (FR-019)
- [ ] T045 [P] `verify_command_test.dart` — preflight red →
      `PREFLIGHT_RED`, no mutation, exit non-zero (FR-013)
- [ ] T046 [P] `verify_command_test.dart` — tool unavailable →
      `NOT_ASSESSED`, exit non-zero (FR-015)
- [ ] T047 [P] `verify_command_test.dart` — survived mutant →
      `FAIL_SURVIVED`, exit non-zero (FR-017)
- [ ] T048 [P] `verify_command_test.dart` — `verification.md` lists
      affected behavior ids + source criteria (FR-018)
- [ ] T049 [P] `verify_command_test.dart` — non-sensitive repro
      diagnostics: runner command, exit code, elapsed, report path;
      no secrets (FR-020)
- [ ] T050 [P] `verify_command_test.dart` — no behavior artifacts
      registered → `NOT_ASSESSED — no behavior artifacts registered`,
      exit non-zero (FR-012)

## Phase 9: Mutation-test.xml scope extension

- [ ] T051 Add the new files (`gen_command.dart`, `verify_command.dart`,
      `artifact_registry.dart`, `behavior_test_writer.dart`,
      `subject_writer.dart`, `mutation_scope.dart`,
      `mutation_auditor.dart`, `source_restorer.dart`) to
      `mutation-test.xml`'s scope

## Phase 10: Verification (the deliverable)

- [ ] T052 `dart format .` and confirm zero diff
- [ ] T053 `dart analyze` and confirm zero errors
- [ ] T054 `dart test` and confirm full suite green
- [ ] T055 Run `zfa tdd verify --feature 044-test-tdd-generation`
      against the real implementation; produce
      `specs/044-test-tdd-generation/tdd/verification.md` from the
      REAL run (not a stale copy)
- [ ] T056 Commit + push branch `044-test-tdd-generation`
- [ ] T057 Create PR targeting `master`
