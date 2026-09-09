**Template Version**: `zuraffa-1.0`

# Tasks: 1330-acceptance-make-no-op-entity-exists

Dependency-ordered, MVP-first. T2-T3 are the behavioral MVP (the red-green
loop drives them); T1 is the fast-test harness the loop runs against; T4 is
the real-CLI wedge proof; T5-T6 are the non-behavioral wiring.

## 1. Test harness (mvp)

- [x] **T1** (P1) `test/plugins/tdd/issue_1330_make_subject_edit_fallback_test.dart`:
  fast make-level tests — (a) the fallback fires on the gated
  entity-exists shape (fallback lines printed, `verdict: no-op` absent,
  hand-tuned entity byte-identical); (b) the subject-edit-less shape keeps
  the #826 verdict verbatim. Traces: SC-1, SC-4 (FR-001, FR-004).
  Depends: —.

## 2. Subject-edit fallback (mvp)

- [x] **T2** (P1) `make_command.dart`: in the bug-#826 no-op pre-flight,
  before aborting, consult the new `_subjectEditFallbackPlan` — when the
  remaining steps carry a subject-edit step (`tdd wire` / `tdd func`),
  print the fallback lines and reassign `effectivePlan` to the reduced
  plan (the no-op make step dropped). Traces: FR-001, FR-003. Depends: T1.
- [x] **T3** (P1) `make_command.dart`: add `_subjectEditFallbackPlan` +
  `_isSubjectEditStep` beside `_bareMakeName`/`_innerMakePlanIsEmpty`
  (self-contained, fail-closed: null unless the first step is the bare
  make shape AND a subject-edit step remains). Traces: FR-001, FR-004.
  Depends: —.

## 3. Real-CLI wedge proof (mvp)

- [x] **T4** (P1) `test/plugins/tdd/scenarios/sc_024_acceptance_entity_reuse_e2e_test.dart`:
  (a) make-level e2e — real `bin/zfa.dart`, no `--zfa-bin` reaching the
  make child, pre-seeded hand-tuned entity → `outcome=green` via the wire
  step, entity byte-identical; (b) run-driver e2e — TWO acceptance
  behaviors referencing the same contract row → `result=complete`, no
  make deferral, no `no-op`, no `stopped_at`. Traces: SC-2, SC-3
  (FR-002). Depends: T2, T3.

## 4. Verification

- [x] **T5** (P1) `tdd/verification.md`: red evidence (pre-fix runs), green
  evidence, targeted test runs (analyze + changed-file tests only; no full
  suite on cloud agents), SC coverage. Depends: T1-T4.

## 5. Wiring / non-behavioral

- [x] **T6** (P2) Spec-kit artifacts (spec.md, plan.md, tasks.md,
  tdd/test-list.md) committed with the code; cross-artifact drift check
  (FR ↔ task ↔ test-list traceability). Depends: T1-T5.
