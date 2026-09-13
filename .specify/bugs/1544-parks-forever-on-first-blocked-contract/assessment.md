# Bug Assessment: `tdd run` parks forever on the first BLOCKED contract — no run-level continue-after-blocked

- **Slug**: 1544-parks-forever-on-first-blocked-contract
- **Created**: 2026-09-13
- **Source**: https://github.com/arrrrny/zuraffa/issues/1544
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Issue #1544 (arrrrny/zuraffa): `zfa tdd run` stops the WHOLE lane at the first
BLOCKED contract behavior. `blocked` is a legitimate per-behavior verdict
(issue #1007 — the declared contract is unsatisfied), but at the RUN level the
driver treats it as a terminal stop of the lane: the run stops with
`result=blocked stopped_at=contract:A1:verify-red`, and every resume re-enters
at the SAME behavior's verify-red. The remaining contract behaviors
(A2..A11) can never be reached, and each resume costs a full refactor pass
(~1h) for zero progress.

Reproduction from the issue:

```
zfa tdd run 001-todo-app --timeout 90
# [run] contract:A1 verify-red -> blocked
# run: result=blocked pending=12 red=0 green=40 done=0 blocked=1 stopped_at=contract:A1:verify-red

zfa tdd run 001-todo-app --timeout 90
# [run] contract:A1 verify-red -> blocked        ← SAME behavior re-attempted
# run: result=blocked ... stopped_at=contract:A1:verify-red
```

## Symptom (verified against the code on this branch)

`lib/src/plugins/tdd/commands/run_driver_core.dart` — the issue-#1007 arm in
`_driveBehavior` advanced the behavior to `BehaviorState.blocked` and returned
a run-terminal stop:

```dart
return (
  state: updated,
  stop: (
    result: 'blocked',
    stoppedAt: '${row.id}:verify-red',
    exitCode: _exitStopped,
    message: null,
  ),
  refactorBlocked: false,
);
```

The phase-1 loop treats any non-null `stop` as the end of the driving pass
(the blocked stop is the ONLY non-error verdict that terminates the loop at a
still-undriven tail of the list), so:

1. **No continue-past-blocked** — behaviors after the blocked contract are
   never driven in that pass (FR-007 bounded progress is forfeited for them).
2. **No resume-skip** — `_stepsFor(BehaviorState.blocked, ...)` re-enters at
   verify-red (spec 1007's designed resume window), so an unchanged world
   re-runs the same full contract cycle every resume and re-blocks
   identically.

## Root cause

The #1007 remediation (restoring the blocked verdict lost in the spec-1008
split, bug #1107) correctly re-introduced the PER-BEHAVIOR verdict but kept
the PRE-#1007 run-level coupling: park + stop-the-lane in one arm. The two
concerns need to separate — the verdict (state machine) stays, the lane
termination goes.

## Expected behavior (from the issue)

1. Resume must not re-attempt a still-blocked behavior unless something
   changed (seam file, contract row, implementation). Skip unchanged blocked
   with receipt (`skipped: still blocked since <ts>`).
2. Continue past blocked in the same run: blocked behaviors are parked, not
   fatal — drive A2..A11 to their own verdicts, then stop with
   `result=blocked blocked=N`.
3. (Alternative escape flags — not needed once 1+2 land.)

## Constraints

- Fix ONLY the run driver's blocked handling and resume logic; do NOT change
  the blocked verdict itself, the contract lane, or the state machine.
- Must not break resume for non-blocked scenarios.
- `dart analyze` with no new warnings.
- Related: #1007 (blocked verdict origin), #1107 (verdict lost in the split).

## Remediation (implemented — see fix.md)

- Park + continue: the blocked arm advances to BLOCKED (unchanged) and
  returns `stop: null`; the loop drives the remaining behaviors.
- Phase 2a skips parked behaviors (make never spawns for a blocked contract —
  the #1007 constraint now enforced in the phase the park newly reaches).
- End-of-pass terminal: `result=blocked blocked=N`, `stopped_at=<first
  blocked>:verify-red`, exit 1, with the resume hint and any refactor/widget
  skip blocks printed beside it.
- Resume skip: an already-blocked contract behavior whose blocked verdict's
  receipt exists AND whose seam file, contract row (`tdd/test-list.md`) and
  implementation (`lib/`) are all older than the verdict is skipped with
  receipt; any change signal (or a missing/unreadable receipt) fails open and
  re-drives the behavior honestly.
