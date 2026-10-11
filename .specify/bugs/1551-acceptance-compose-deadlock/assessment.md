# Assessment — #1551 TDD run deadlocks at A1: acceptance compose requires a green/wired unit but units are not yet driven

Date: 2026-09-13
Branch: `fix/1551-acceptance-compose-deadlock`
Scope: the compose precondition grading ONLY — `lib/src/plugins/tdd/commands/make_command.dart`. No compose-surface, state-machine, or loop-semantics edits.

## Evidence (reproduced on pristine master, commit 4d1dafc)

A fresh project, first-ever `zfa tdd run 001-barcode-scan` (the issue's
reproduction shape — an acceptance row A1 followed by unit rows in id order):

```
[run] A1 gen -> ok
[run] A1 verify-red -> certified
[run] A1 make -> generation-error
zfa tdd run: step failed — behavior=A1 step=make outcome=generation-error
run: feature=001-barcode-scan result=stopped pending=1 red=1 green=0 done=0 stopped_at=A1:make
```

(Full transcript: `tdd/verification.md` §3, RED run. The issue's own
30-behavior reproduction shows the identical shape with `pending=30`.)
Every resume re-stops identically at `A1:make` — the units that would
satisfy the precondition are never reached — a hard deadlock on every
fresh project. Regression introduced by fix(1512) (commit 7d93b09); a
pre-existing slow-tier pin (`make_command_test.dart` A10) already
red-flagged the new grading on master.

## Root cause

A capability whose precondition is "a unit is green/wired" is scheduled
before the behaviors that produce those preconditions, and the unmet
precondition is graded a HARD STOP instead of a deferral — even though
the driver already has a deferral mechanism for exactly this shape.

The chain, file by file:

1. **fix(1512), `generation_planner.dart` branch 3b** — every acceptance
   row that names no entity signal now routes to an EXPRESSIBLE plan:
   `[tdd compose <id> --feature <f>, build]` (the spec-052 composition
   lane). Pre-#1512 this shape fell to branch 4's generic misfire and the
   make reported `unexpressible`.
2. **Fresh-project ordering** — the run driver walks behaviors in id
   order (A1 before any U*). At A1's make the feature holds ZERO
   composable unit anchors: no unit is green and none carries the
   `wiredEntityAnchor` marker (`zfa tdd wire` has not run; the prescribed
   remedy itself requires U1 to be gen'd first).
3. **`compose_command.dart` + `composition_targets.dart` (unchanged,
   correct)** — the compose command fail-closes honestly:
   `no green unit subjects to compose against ...`, final summary line
   `compose: behavior=A1 outcome=no-green-units ...`, exit 1.
4. **`make_command.dart`, the pipeline-failure handler (THE DEFECT)** —
   the failed compose step (a child whose failure is an UNMET
   PRECONDITION, not a generation defect) falls through to the generic
   grading: `MakeOutcome.generationError`. The compose child's own
   machine verdict (`outcome=no-green-units` in its captured output) is
   never consulted.
5. **`run_driver_core.dart` (unchanged, correct)** — the driver's
   deferral arm (`step == 'make' && (outcome == 'unexpressible' ||
   outcome == 'no-op')` → `deferred (phase 2)`, the bug #625/#826
   contract) cannot match `generation-error`; the generic failure stop
   fires: `result=stopped ... stopped_at=A1:make`. Phase 2a (which
   re-attempts deferred makes AFTER the units are driven — exactly where
   the anchor precondition IS satisfiable) is never reached.

The pre-#1512 shape for this same state (zero composable anchors) was
make's `unexpressible` token — the token the deferral arm consumes. The
#1551 defect is therefore a grading regression at one call site, not a
loop or compose design flaw.

Related: #1512 (introducing change), #1550 (stale cache variant of the
family), #923/#1162 (anchor widening — green OR wired OR bug-feature
stub), #625/#826 (the deferral contract this fix feeds).

## Remedy selected (issue option 1 — "defer, don't stop")

Map the compose step's `no-green-units` precondition verdict to make's
`unexpressible` outcome, so the driver's EXISTING deferral arm defers the
behavior to phase 2. Only the grading changes: the compose command keeps
its honest `no-green-units` stop for direct callers (surface untouched),
the state machine is untouched, and the loop semantics are untouched —
`unexpressible` already defers. Options 2 (lane ordering) and 3
(optional anchors) were rejected: lane ordering edits the driver loop
(a hard-constraint violation) and reorders every feature, while optional
anchors weaken the compose precondition for every caller instead of
deferring the one behavior whose anchor is pending.

## Constraints honored

- Fix ONLY the compose precondition check (its grading in make) —
  `compose_command.dart`, `composition_targets.dart`,
  `composition_planner.dart`, `generation_planner.dart`,
  `run_driver_core.dart` are byte-identical to master.
- Acceptance compose when units ARE green: unchanged (pinned by the new
  bug-1551 suite pin 3 and the pre-existing spec-052 suites).
- `dart analyze` on the changed files: no issues.
