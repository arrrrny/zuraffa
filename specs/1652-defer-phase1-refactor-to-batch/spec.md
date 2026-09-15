**Template Version**: `zuraffa-1.0`

# Spec: 1652-defer-phase1-refactor-to-batch

## Overview

On a forward `zfa tdd run`, every behavior pays one phase-1 refactor spawn
— full-suite preflight, whole-project pass registry (`zfa build`,
`dart format lib/`, `dart fix --apply lib/`), re-proof — immediately
after its make just certified the tree green (issue #1652). The #1624
pass-batch ledger cannot absorb this: forward progress changes `lib/`
on every make (each behavior adds its subject file), breaking the
ledger's byte-identity precondition by construction, so the ledger only
ever inherits for spawns that changed nothing — the exact case that does
not need it. Measured on the zcalc probe (full suite ≈ 12 s): ~26 s of
refactor per behavior, of which ~15 s is the full-suite preflight and
~10 s the pass registry — repeated N times for N behaviors, ~50% of the
per-behavior cycle cost. At real-suite scale this is
O(behaviors × suite-time) per feature spent re-proving what the run
itself proved seconds earlier.

Two remedies were proposed. Proposal 2 — the digest gate — is already on
master (PR #1662): the run records make's certified post-state and a
matching `--pass-batch` spawn inherits make's evidence. That record is
**best-effort derived data**: every mismatch dimension the design names
(tree drift, a corrupt or mistyped record, a failed record write, a
baseline/config/suite-template/exempt-set change) costs the spawn a FULL
pipeline — and in the forward shape that cost repeats PER BEHAVIOR,
because each behavior's phase-1 spawn is separated from the next make by
nothing but the spawn itself. Proposal 1 — this feature — makes the
economics structural instead of conditional:

**the phase-1 refactor reached in the same drive whose make just
certified the behavior green is DEFERRED into the existing phase-2b
batch pass, unconditionally.** Phase 2b (bugs #635/#734; issue #922)
already refactors every green behavior with the pass-batch ledger opted
in (#1588/#1624), and there — with ALL makes complete — the tree is
byte-stable across the batch: the first spawn pays at most one full
pipeline and records the ledger (or inherits make's post-state record
when it still matches), and every subsequent spawn inherits. The
full-suite gate goes from N per run to at most one per lane per run,
robustly, even when the best-effort record is missing or stale. As a
side effect the eager per-behavior refactor spawn leaves the forward
path entirely: the deferral is a print and a state save.

The redundancy the deferral removes is structural: between a behavior's
make-green and its refactor step, no human and no external process
touched the tree — the loop is machine-driven inside one `tdd run`
invocation. Make's skip transition (#741) already avoids re-running the
suite after green; the phase-1 refactor immediately re-ran it anyway.

Scope guard (hard constraints from the issue): the fix touches ONLY the
phase-1 refactor scheduling inside the run driver's step loop. The
phase-2b batch pass, the pass-batch ledger
(`pass_batch_ledger.dart`), the make-post-state record
(`make_post_state.dart`, PR #1662), and the make skip logic are
untouched. A refactor step reached WITHOUT a make in the same drive
(resume re-entry for a green/mocked behavior) keeps its existing
deferral semantics and still runs in phase 1 when the suite is
otherwise fully green — the existing #1624 phase-1-spawn contract
(`bug 1624: a phase-1 refactor spawn carries --pass-batch`) is
preserved verbatim.

## Acceptance Scenarios

1. **Given** a forward run where a behavior's make certifies it green
   during the phase-1 drive (the reported zcalc shape: gen → verify-red
   → make in one uninterrupted pass), **When** the drive reaches that
   behavior's refactor step, **Then** the refactor is DEFERRED to the
   phase-2 batch pass — no `zfa tdd refactor` subprocess is spawned in
   phase 1 (absent from the zfa argv log), the driver prints the
   existing `[run] <id> refactor -> deferred (phase 2)` line, and the
   per-behavior cycle pays zero preflight/registry cost after make.
   **Type**: acceptance
2. **Given** the same run reaching the phase-2b batch pass with N green
   behaviors, **When** the batch refactors the behaviors in list order,
   **Then** the full-suite gate still fires at most once per lane per
   run — the first batch spawn either pays the full pipeline and
   records the pass-batch ledger (#1588/#1624, untouched) or inherits
   make's post-state record when it matches (PR #1662, untouched), and
   every subsequent batch spawn on the byte-stable tree inherits the
   gate — all N spawns carry `--pass-batch`.
   **Type**: acceptance
3. **Given** a resumed run where a behavior re-enters phase 1 directly
   at refactor (its state is already green/mocked from a previous run,
   no make runs in this drive), **When** the suite is otherwise fully
   green with no pending-with-artifacts behaviors, **Then** the refactor
   runs in phase 1 exactly as before — the pre-#1652 window for
   non-forward re-entry is unchanged (SC-3 for resume shapes; the
   #1624 phase-1 spawn still carries `--pass-batch`).
   **Type**: acceptance
4. **Given** a hand-stepped behavior (#1568: make stopped
   `generation-error` on a planner-declared hand-step seam) or a
   blocked contract (#1007/#1544: verify-red parked it), **When** the
   run drives the remaining behaviors, **Then** neither shape's refactor
   behavior changes — hand-steps keep their honest red with
   `stopped_at=<id>:hand`/`hand_steps=N` reporting, blocked contracts
   keep their park with `result=blocked blocked=N`, and neither ever
   reaches the new deferral arm (make never succeeded for them).
   **Type**: acceptance
5. **Given** a forward run where a LATER behavior's make fails (honest
   stop) before phase 2b, **When** the run stops, **Then** the already-
   made behaviors keep their green state with deferred refactors — no
   refactor evidence is fabricated, no phase-2b pass runs, and the
   resume re-drives them through the same deferral into a later batch
   pass (bounded, resumable progress, FR-007; never a fake DONE,
   FR-008).
   **Type**: acceptance

## Functional Requirements

- **FR-001**: The run driver's step loop MUST defer a phase-1 refactor
  step to the phase-2 batch pass when the behavior's make certified it
  green during the SAME drive (either make success arm: the normal
  green landing or the #694/#1331/#1345/#1398
  skip/adopt/adopted-placeholder/adopted-interrupted transitions),
  regardless of the suite's red/pending state.
- **FR-002**: The deferral MUST use the existing deferral machinery —
  the same `[run] <id> refactor -> deferred (phase 2)` line, the same
  phase-2b re-drive, the same state advance semantics — so the phase-2b
  pass, the ledger, and the journal see no new shapes.
- **FR-003**: A phase-1 refactor reached WITHOUT a same-drive make (the
  resume re-entry window from `_stepsFor`) MUST keep its pre-#1652
  deferral predicate (suite has reds OR pending-with-artifacts) and run
  in phase 1 when the suite is fully green, carrying `--pass-batch`
  (#1624) as before.
- **FR-004**: The deferral predicate evaluation MUST remain
  suite-global in the existing direction: the new same-drive-make
  condition may only cause an EARLIER deferral (fewer phase-1 spawns),
  never suppress a deferral the old predicate already produced.
- **FR-005**: No state machine transitions change: `refactor` success
  still lands DONE via the existing `_targetStateFor`, a deferred
  refactor still leaves the behavior at its pre-deferral state (green),
  and the completion gate (`allDone`) still requires every behavior
  DONE through the phase-2b pass.

## Hard Constraints

- Fix the phase-1 refactor scheduling ONLY. Do NOT change the phase-2b
  batch pass, the pass-batch ledger (`pass_batch_ledger.dart`), the
  make-post-state record (`make_post_state.dart`), or the make skip
  logic (#694/#741).
- One PR per feature.
- The flag-less standalone `zfa tdd refactor` absolute-green contract
  (spec 048 FR-001) is untouched — no spawned refactor changes shape.

## Success Criteria (measurable)

- **SC-1**: Driver-level test (scripted fake zfa, fast tier): a forward
  run with unit behaviors whose make scripts green shows ZERO
  `tdd refactor` spawns before the phase-2b pass, with the deferral
  line printed per behavior and every behavior DONE at completion.
- **SC-2**: The same driver-level test shows every refactor spawn
  happening AFTER the last make of the run (all gen/verify-red/make
  steps of all behaviors precede all refactor spawns), each carrying
  `--pass-batch` (#1588/#1624 argv contract), and the run completes
  `result=complete pending=0 red=0 done=N`.
- **SC-3**: The existing bug-1624 resume-re-entry test (state green,
  green evidence, no make in drive) passes UNMODIFIED — the phase-1
  refactor spawn still happens exactly once there and still carries
  `--pass-batch`.
- **SC-4**: The deferral-adjacent suites pass —
  `bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart` (all
  three tests), `bug_922_refactor_preflight_baseline_test.dart`,
  `bug_1652_refactor_make_post_state_test.dart` (command level) and
  `run_driver_1652_make_post_state_test.dart` (driver level) pass
  UNMODIFIED; `two_cycle_run_commands_test.dart` passes with its pinned
  step sequences updated to the new schedule (those sequences pinned
  exactly the per-behavior phase-1 refactor this fix removes — the
  update is documented in the cycle log).
- **SC-5**: On the zcalc probe class (4 unit behaviors), per-behavior
  refactor wall-time after make drops from ~26 s to the cost of a print
  + state save (sub-second); the run's full-suite refactor gate becomes
  at most one pipeline per lane in phase 2b, and stays there even when
  the best-effort make-post-state record misses (corrupt record, write
  failure, drift) because the byte-stable phase-2b tree lets the #1588
  ledger cover the remaining behaviors.
- **SC-6**: `dart analyze` on the changed files reports zero new issues
  versus the pre-change baseline, and `dart format` is clean on them
  (CI format gate).

## Assumptions

- The zcalc probe (issue #1652 evidence) is an external fixture; SC-5's
  claim is verified here at the driver level (zero phase-1 spawn cost =
  sub-second deferral) plus the #1588 ledger economics already covered
  by the command-level suite-count tests.
- Mutation evidence for `tdd/verification.md` is scoped to the changed
  scheduling predicate (the same-drive-make condition): killing the
  mutation must flip the new SC-1 test to red. Whole-file mutation
  testing of `run_driver_core.dart` is out of budget (4123 lines; the
  repo's `mutation-test.xml` scopes to the 041 writers, not this file).
