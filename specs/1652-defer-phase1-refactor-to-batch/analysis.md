# Analysis Report: 1652-defer-phase1-refactor-to-batch

**Generated**: 2026-09-16 (analyze pass over spec.md, plan.md, tasks.md)

## Traceability matrix (spec ↔ tasks)

| Spec element | Tasks | Status |
| --- | --- | --- |
| AC-1 forward deferral | T001 (A1), T003 (U1 skip variant) | COVERED |
| AC-2 batch-boundary gate | T002 (A2) | COVERED (see N-1 below) |
| AC-3 resume window | T004 (U2) + existing bug-1624 test | COVERED |
| AC-4 hand-step / blocked contract | T006 (U4); hand-step shape via existing bug_1568 suite (SC-4 class) | COVERED |
| AC-5 honest stop | T005 (U3) | COVERED |
| FR-001 | A1, A2, U1, U4 | COVERED |
| FR-002 | A1 (deferral line asserted) | COVERED |
| FR-003 | U2, U4 | COVERED |
| FR-004 | A2 (old predicate subset — the red/pending deferral suites still pass, SC-4) | COVERED |
| FR-005 | A1 (DONE lands), U3 (no fabricated evidence) | COVERED |
| SC-1..SC-6 | T001–T006, T101–T104 | COVERED |

## Findings and resolutions

1. **N-1 (coverage nuance, resolved)** — AC-2's "at most one full
   pipeline per lane per run" cannot be asserted as a suite-spawn count
   in the driver-level fake-zfa harness (the fake refactor children are
   scripts; they spawn no suite). Resolution: the driver suite asserts
   the scheduling (all makes precede all refactors; every spawn carries
   `--pass-batch`; completion), while the pipeline-count economics are
   carried by the UNMODIFIED #1588 command-level suite (its logging
   wrapper counts real suite spawns) plus the hard constraint that
   phase-2b code is untouched. Spec SC-5 wording already reflects this
   split; tasks T003/T103 reference the right suites.
2. **N-2 (drift risk, resolved)** — T102 updates pinned step sequences
   in `two_cycle_run_commands_test.dart`. That suite pins the
   per-behavior phase-1 refactor AFTER make — exactly the scheduling
   this feature removes. The update is a test-expectation change only
   (no production phase-2b change), is scoped to the pinned sequences,
   and must be documented in the cycle log. The plan's Verification
   section and spec SC-4 both name this honestly instead of claiming
   "unmodified".
3. **N-3 (constraint audit, clean)** — the planned code change touches
   only `_driveBehavior` in `run_driver_core.dart`: one local boolean,
   two assignments, one `||` extension. No phase-2b, ledger,
   make-post-state, or make-skip edits. Verified against the hard
   constraints in spec.md.
4. **N-4 (composition, clean)** — PR #1662's `recordMakePostState`
   calls stay on both phase-1 and phase-2a call sites; the deferral
   changes nothing about when the record is written (at make-green),
   only removes the spawn that used to consume it between makes. The
   first phase-2b spawn becomes the record's consumer. No interaction
   hazard.
5. **N-5 (mocked-state stranding, avoided)** — deferring the resume
   re-entry window unconditionally would strand MOCKED behaviors
   (phase-2b iterates `green` only). FR-003/T004 keep the resume
   window on the old predicate; the plan records the rejected
   alternative.

## Verdict

PROCEED. No unresolved drift: every acceptance scenario, functional
requirement, and success criterion maps to at least one task; the two
test-expectation updates (T102) are the fix's own observable scheduling
change and are documented as such.
