**Template Version**: `zuraffa-1.0`

# Spec: 1330-acceptance-make-no-op-entity-exists

## Summary

When a contract-row entity already exists, `zfa tdd make` for an acceptance
behavior plans `zfa entity create` (reused) + `zfa make <Row>` — but
`zfa make <Row>` is a one-shot scaffold that resolves to "no active plugins —
nothing to generate (bug #826)" on an already-generated entity. The
subject-edit fallback that turned the earlier sibling behaviors green is never
applied, the test stays red, the verdict is `no-op`, and the run dead-ends:
phase 2 retries the identical plan, gets the identical no-op, and the run
stops at `make -> no-op` (`result=stopped stopped_at=<id>:make`). This feature
makes the gated one-shot make FALL BACK to the plan's subject-edit step
instead of hard-stopping, so multiple behaviors referencing the same contract
row complete. The core engine cycle, the entity scaffold, the plugin system
(bug #826), and the verify gate are untouched.

## Acceptance Scenarios

1. **Given** an acceptance (or entity-traced) behavior whose entity-create
   step was gated away because the contract-row entity already exists, and
   whose remaining plan still carries a subject-edit step (`tdd wire` /
   `tdd func`) **When** the inner `zfa make <Row>` resolves to zero active
   plugins (nothing to generate) **Then** `zfa tdd make` drops the no-op
   make step, proceeds with the remaining pipeline (the subject edit runs,
   the build runs), and the post-generation target re-run grades the real
   outcome — the no-op is NOT a hard stop and the subject stub is edited by
   the same path that turned the earlier sibling behaviors green.
2. **Given** the subject-edit fallback has been applied to a behavior's make
   **When** the run driver evaluates the step result **Then** the make
   reports a real outcome (`green`, or an honest failure such as
   `generation-error`) and NEVER `no-op`, so the driver's deferral arm never
   defers the behavior and phase 2 never re-plans the identical steps — the
   behavior advances (its test was verified red, the subject edit makes it
   green in the same phase), and the run no longer wedges at
   `stopped_at=<id>:make` for any lane-format feature where two behaviors
   reference the same contract row.
3. **Given** the contract-row entity was previously generated (or
   hand-tuned) **When** the fallback drops the no-op make step **Then** the
   entity file is reused AS-IS — the entity is never regenerated, never
   overwritten, and hand-tuned fields survive byte-identical (the #829
   reuse contract holds through the fallback path).
4. **Given** a first-time entity (entity file absent) **When** the behavior's
   make runs **Then** the normal scaffold path is unchanged (`entity create`
   runs, the pipeline generates against it); and **Given** a plan whose
   bare `make <Row>` step resolves to nothing and which carries NO
   subject-edit step **When** the make runs **Then** the bug #826
   `verdict: no-op` is preserved verbatim (fail-closed backward
   compatibility — the fallback only fires where a subject-edit path exists).

## Functional Requirements

- **FR-001** (subject-edit fallback on no-op): In `zfa tdd make`, when the
  bug-#826 pre-flight detects an inner `zfa make <Row>` that resolves to
  zero active plugins AND the effective plan (after the #829 entity-create
  gate) still carries at least one subject-edit step (`tdd wire` or
  `tdd func`), the make MUST drop the no-op `make <Row>` step and continue
  executing the remaining plan through the pipeline. The fallback line
  MUST be printed (never silent) naming the resolution, the entity reuse,
  and the dropped step.
- **FR-002** (no phase-2 identical re-attempt): With FR-001 applied, the
  make MUST NOT report `outcome=no-op` — the summary carries the real
  post-pipeline outcome — so the run driver's deferral arm
  (`unexpressible` | `no-op`) never engages for the entity-exists case and
  phase 2 never re-plans identical steps. (The pure no-op shape with no
  subject-edit step keeps the designed #826 deferral, where plugins may
  legitimately land between phases.)
- **FR-003** (entity reuse preserves hand-tuned fields): The fallback MUST
  NOT re-create or regenerate the entity: the #829 gate already dropped the
  `entity create` step and the fallback only REMOVES the no-op make step —
  the entity file is never opened for writing by the fallback path.
- **FR-004** (backward compatibility): The fallback fires ONLY when (a) the
  effective plan's FIRST step is the bare `make <Row>` shape the #826
  pre-flight can mirror, (b) that inner plan resolves to zero active
  plugins, and (c) a subject-edit step remains. Entity-absent scaffolds
  (plan starts with `entity create`) and subject-edit-less plans keep the
  exact pre-#1330 behavior.
- **FR-005** (hard constraints preserved): The core engine cycle
  (`run_driver_core.dart` step sequencing, deferral arms, honest stop), the
  entity scaffold implementation (`zfa entity create`), the plugin system
  and its resolution (bug #826), and the verify gate are unchanged.
  `zfa make` is NOT made retryable or idempotent — the one-shot scaffold
  still no-ops on second+ runs; only `zfa tdd make`'s reaction changes.

## Success Criteria

- **SC-1** (AC1): A make-level run on a fixture whose entity file exists
  (hand-tuned marker content) with an acceptance/entity-traced behavior and
  NO generator plugins shows the fallback line, does NOT show
  `verdict: no-op`, and leaves the entity file byte-identical.
- **SC-2** (AC1, real CLI): With the REAL pipeline (forwarder to
  `bin/zfa.dart`, no `--zfa-bin` flag reaching the make child), the gated
  make certifies `outcome=green` through the `tdd wire` subject edit; the
  green evidence records the wire step; the entity file is byte-identical.
- **SC-3** (AC2, wedge proof): A real `zfa tdd run` over TWO acceptance
  behaviors referencing the same contract row (the issue repro shape)
  completes `result=complete` with both behaviors done — no
  `make -> deferred`, no `no-op`, no `stopped_at`.
- **SC-4** (AC4): The bug #826 verdict is preserved for the
  subject-edit-less shape (`verdict: no-op` + `no subprocess was attempted`
  + exit 1), and the existing #826/#829/#731 suites pass unchanged.
