# Issue — #1551 tdd: fresh-project run deadlocks at A1 (acceptance compose hard-stops on the no-green-units precondition)

## Reproduction (fresh project, first-ever run)

```bash
zfa tdd run 001-barcode-scan --timeout 180
# [run] A1 gen -> ok
# [run] A1 verify-red -> certified
# [run] A1 make -> generation-error
#   zfa tdd compose: no green unit subjects to compose against
#   compose: behavior=A1 outcome=no-green-units
# run: result=stopped pending=30 red=1 green=0 done=0 stopped_at=A1:make
```

The run stops at the FIRST behavior. The acceptance compose surface
(from `fix(1512)`) requires a green/wired unit subject — but the driver
walks behaviors in id order (A1..A12 before U1..U14). No unit exists
yet. The prescribed remedy (`zfa tdd wire U1 --entity ...`) itself
requires U1 to have been gen'd first. Every resume re-stops identically:
the loop is deadlocked on fresh projects.

## Root cause

A capability whose precondition is "a unit is green" is scheduled before
behaviors that produce those preconditions, and the unmet precondition
is a **hard stop** rather than a deferral — even though the driver
already has a deferral mechanism for this shape
(`make -> unexpressible -> deferred (phase 2)`).

fix(1512) (commit 7d93b09) made the planner route every acceptance row
without an entity signal to the spec-052 composition plan
(`tdd compose <id> --feature <f>` → build). When the compose step
fail-closes with `outcome=no-green-units`, the make graded that child
failure as `generation-error` — a token the driver's deferral arm
(`unexpressible` / `no-op`) can never match.

## Expected

1. **Defer, don't stop** (SELECTED): `compose ...
   outcome=no-green-units` maps to `deferred (phase 2)`, not
   `runner-error`/`generation-error`. Phase 2 (after units green/wired)
   composes acceptance behaviors.
2. ~~Or order lanes: drive unit-kind before acceptance-kind within a
   feature~~ (rejected: edits the driver loop; a hard-constraint
   violation).
3. ~~Or make anchor optional: compose against composable unit stubs if
   no unit green yet~~ (rejected: weakens the compose precondition for
   every caller; the bug-feature stub lane #1162 already covers the
   sanctioned stub-anchor case).

## Hard constraints

- Fix ONLY the compose precondition check or lane ordering. Do NOT
  change the compose surface itself, state machine, or loop semantics.
- Must not break acceptance compose when units ARE green.
- Must pass `dart analyze` with no new warnings.
- Introduced by `fix(1512)` — regression on fresh projects.
- Related: #1512 (acceptance compose surface), #1550 (stale cache
  variant).
