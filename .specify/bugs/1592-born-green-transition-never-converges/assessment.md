# Bug Assessment: [BUG] born-green transition never converges — blocked contracts loop forever

- **Slug**: 1592-born-green-transition-never-converges
- **Created**: 2026-09-13
- **Source**: https://github.com/arrrrny/zuraffa/issues/1592
- **Verdict**: valid — root cause located, reproduced at the unit level
- **Severity**: high (the designed recovery from the #1411 catch-22 is itself a dead end for blocked contract behaviors — the operator cannot make progress by any supported path)

## Report (verbatim or summarized)

Born-green transition never converges. After implementing seams and running
`zfa tdd make <id> --born-green` (exit 0, green evidence written), a re-run
of `zfa tdd run` stops at the same `make` → `not-certified-red` and
prescribes the exact command that already ran. Every re-run repeats the
identical stop — the loop never converges.

## Symptom

1. `zfa tdd run` parks a contract behavior as `BLOCKED` (the #1007 verdict,
   parked per #1544).
2. The operator hand-implements the seams and certifies the born-green hand
   transition: `zfa tdd make <id> --born-green` — exit 0, a `kind: green`
   evidence entry lands in `tdd/cycle-log.md`.
3. `zfa tdd run` re-drives the blocked behavior at `verify-red`, the
   already-green test grades `unexpected-green` (skipped, no evidence
   written), `make` refuses `not-certified-red`, and the #1411 hand-stop arm
   fires with the born-green prescription — the command the operator
   ALREADY ran.
4. Re-run repeats step 3 identically. Infinite prescription loop.

## Reproduction

See `issue.md`. Driver-level (the scripted fake-zfa convention): a blocked
contract behavior whose cycle-log carries backed green evidence, with
verify-red scripted `unexpected-green` and make scripted
`not-certified-red`, reproduces the stop verbatim pre-fix.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/run_driver_core.dart` — `_stepsFor`
  (line ~1373): the resume-window computation.
  - `BehaviorState.blocked => 1` (spec #1007): a BLOCKED contract behavior
    re-enters at `verify-red`.
  - The #1324 green-evidence guard: `if (start == 0 && hasGreenEvidence &&
    greenTestBacked)` — fires ONLY when the computed window starts at `gen`
    (`start == 0`).
- `lib/src/plugins/tdd/commands/run_driver_core.dart` — the make
  `not-certified-red` stop arms (#912/#1373/#1411, line ~1818–1956): the
  born-green prescription printer.
- `lib/src/plugins/tdd/commands/run_driver_core.dart` — `_certifiedGreenBacked`
  (line ~2263): the current-generation backing check that feeds
  `greenTestBacked`.

## Root Cause (confirmed)

The #1324 green-evidence guard's scope excludes the blocked re-entry window.

`_stepsFor` maps `BehaviorState.blocked` to `start = 1` (spec 1007: an
implemented contract either unblocks the cycle or keeps it honestly
blocked). The #1324 guard then runs:

```dart
if (start == 0 && hasGreenEvidence && greenTestBacked) {
  start = state == BehaviorState.pending ? 2 : 3;
}
```

The guard fires only when `start == 0` — the window that begins at `gen`.
A born-green-certified blocked behavior computes `start == 1` (blocked →
verify-red), so the guard never fires and the cycle re-enters
`verify-red → make`. On the already-green subject verify-red grades
`unexpected-green` (the skip arm sets `sawUnexpectedGreen`), `make` then
refuses `not-certified-red` (a born-green transition certifies green
WITHOUT a prior certified red — there is no red evidence to point at), and
the #1411 arm — which keys on exactly this drive's `sawUnexpectedGreen` +
`not-certified-red` shape — re-prescribes `zfa tdd make <id> --born-green`.
The recovery command and the wedged state are mutually reinforcing: the
loop is structurally unbounded.

This is a coverage gap in the #1324 guard, not a defect in the blocked
verdict, the born-green certification, or the state machine: all three
behave as designed in isolation. The gap is that the guard — written for
the pending/green resume classes — was never extended to the blocked class
when spec 1007 gave blocked behaviors their own re-entry window.

## Proposed Remediation

Extend the #1324 green-evidence guard to include the blocked state (success
criterion 1 of the feature spec): when the cycle-log carries
current-generation green evidence backed by the certified test file on disk
AND the computed window is the blocked re-entry (`start == 1`), resume at
`make` (index 2) — the drift-skip / adoption transition (#694/#1331 via
#1162) re-certifies the born-green hand honestly and the run converges to
`result=complete` without manual re-entry (success criterion 3).

Scope guards:

- Fix ONLY the green-evidence guard scope in `_stepsFor`. The born-green
  certification, the BLOCKED verdict, and the state machine are untouched.
- Behaviors without backed green evidence keep the exact pre-#1592 windows
  (the #1324 SC-4 compat rule): the guard requires `hasGreenEvidence &&
  greenTestBacked` to fire at all, so normal (non-born-green) blocked
  resume — no green evidence — is bit-for-bit unchanged.
- The #1324 `start == 0` arm keeps its exact mapping (`pending → 2`,
  otherwise `3`); the extension adds the `start == 1 && state == blocked`
  case only.

## Risks & Considerations

- **Normal blocked resume**: protected by the evidence gate — without
  backed green evidence the new arm never fires (covered by a dedicated
  regression test).
- **Unbacked green evidence**: a blocked behavior with green evidence whose
  certified test file is gone keeps the pre-#1592 window (re-enters
  verify-red; the #1324 stale-artifacts contract stands — covered by a
  dedicated regression test).
- **Convergence semantics**: resuming at make exercises make's OWN
  re-certification transitions (#694 skip / #1331 adoption) — no new
  certification path is introduced, and the refactor step still runs, so
  the red→green→refactor honesty ledger (#682, with the #1542 contract/born-
  green carve-outs) is unchanged.
- **Adjacent windows**: an in-flight interruption INSIDE the blocked
  verify-red step (in-flight marker `verify-red`) computes `start == 1` via
  the in-flight override too — the same wedge, same fix. The extension
  covers both entry routes because it keys on the computed window, not the
  route.

## Open Questions

- None blocking. Criterion 2 (recognize `kind: green` evidence in the
  phase-1 blocked arm and advance directly) is the OR-alternative; the
  guard extension (criterion 1) is the narrower, spec-aligned fix and is
  what this remediation implements.
