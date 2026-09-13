# Bug Issue: 1592-born-green-transition-never-converges

- **Issue**: https://github.com/arrrrny/zuraffa/issues/1592
- **Title**: Born-green transition never converges — born-green-certified blocked behaviors loop forever
- **Labels**: bug, tdd-run, contract-lane
- **Related**: #1411 (born-green hand transition), #1544 (continue-after-blocked), #1007 (contract lane), #1324 (green-evidence guard), #1589 (first dead-end), #694 (drift-skip), #1162 (subject-shape adoption)

## Report

After implementing the seams and certifying the born-green hand transition
(`zfa tdd make <id> --born-green`), a subsequent `zfa tdd run` stops at the
exact same place it did before the certification: `make` refuses with
`not-certified-red` and prescribes the `--born-green` command that already
ran. Every re-run repeats the identical stop — the transition never
converges and the feature is stuck in a prescription loop.

### Reproduction

```bash
zfa tdd run calculator              # parks the contract behavior as BLOCKED
# hand-implement the seams
zfa tdd make contract:A1 --born-green   # exit 0, green evidence written
zfa tdd run calculator              # exact same stop at step 3, same instruction
# → loop forever
```

## Expected Behavior

A born-green-certified blocked behavior must converge to `result=complete`
without manual re-entry: the run recognizes the backed green evidence and
resumes the cycle at `make` (the drift-skip / adoption transition,
issues #694/#1162), which re-certifies honestly, and the feature completes.

## Actual Behavior

The run re-enters the blocked behavior at `verify-red` (spec 1007's blocked
window), the already-green test grades `unexpected-green`, `make` refuses
`not-certified-red` (no certified red exists for a born-green transition),
and the #1411 hand-stop arm re-prescribes `zfa tdd make <id> --born-green`.
The operator is trapped in a loop: certify → re-run → same stop → certify → …
