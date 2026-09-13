# Issue Record: contract blocked dead-ends resume path + poisons phase-2 refactor

- **GitHub issue**: https://github.com/arrrrny/zuraffa/issues/1589
- **State**: OPEN
- **Title**: BUG 1589 — CONTRACT BLOCKED DEAD-ENDS RESUME PATH + POISONS PHASE-2 REFACTOR
- **Filed by**: arrrrny
- **Related**: #1007 (BLOCKED verdict by design), #1544 (blocked defer + unchanged-skip), #1308 (hand seam), #922 (refactor baseline tolerance), #741 (run baseline cache)

## Note on the report phase

The bug is already tracked as issue #1589; this file records the existing
issue instead of filing a fresh one (no duplicate issue created).

## Issue body (summarized — see the linked issue for the verbatim text)

Blocked contracts dead-end the documented resume path and silently poison
the phase-2 refactor pass. `make` demands red, `verify-red` can never
produce it (BLOCKED by design, #1007):

```
zfa tdd run calculator
# contract:A1 verify-red -> blocked (parked)
# run: result=blocked stopped_at=contract:A1:verify-red

zfa tdd make contract:A1 --feature calculator
# "has no certified-red evidence" → not-certified-red

zfa tdd verify-red contract:A1 --feature calculator
# "blocked — implement declared contract" → no red evidence written
```

Loop: make waits for red that verify-red is forbidden to write. Parked
contracts fail the full suite, the phase-2 refactor gate demands absolute
green, and every refactor is skipped for all remaining behaviors.

Feature spec (measurable success criteria):

1. Blocked stop names the hand surface (seam file path + `zfa tdd wire
   contract:<n>`).
2. `zfa tdd make <contract>` accepts the blocked verdict as a precondition
   or says plainly "implement seam first".
3. Known parked behavior does not fail the phase-2 refactor gate
   (pre-existing-failure economics).
4. Resume instructions are followable as written.

Hard constraints: fix ONLY the blocked-stop messaging, the make
precondition, and the refactor gate for parked behaviors; do NOT change
the BLOCKED verdict itself, the contract lane, or the state machine; must
pass `dart analyze` with no new warnings.
