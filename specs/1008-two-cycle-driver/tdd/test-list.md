# Test List: 1008-two-cycle-driver

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | `zfa tdd run-engine <feature>` drives ONLY the CORE+BOTH behaviors (SKIN rows never spawn steps) and exits 0. | US1.AC1 | DONE |
| U2 | run-engine writes `specs/<feature>/tdd/04-engine-receipt.json` with verdict green, the lane's behavior ids, and honest counts. | US1.AC2 | DONE |
| U3 | run-engine on a legacy (untagged) feature drives every behavior exactly like the pre-split driver (CORE default). | US1.AC3 | DONE |
| U4 | an honestly-stopped engine lane writes its receipt with verdict red and the stopped_at location. | US1.AC4 | DONE |
| U5 | `zfa tdd run-skin <feature>` without an engine receipt exits 2, names the missing receipt and the run-engine remediation, and drives zero steps. | US2.AC1 | DONE |
| U6 | run-skin with a non-green engine receipt exits 2 naming the recorded verdict. | US2.AC2 | DONE |
| U7 | run-skin with a green engine receipt drives ONLY the SKIN+BOTH rows (BOTH rows already done are skipped) and writes the skin receipt. | US2.AC3 | DONE |
| U8 | run-skin over a feature with zero skin behaviors completes vacuously (green receipt, no steps). | US2.AC4 | DONE |
| U9 | `zfa tdd run <feature>` chains engine then skin (engine steps strictly before skin steps), both receipts green, exit 0. | US3.AC1 | DONE |
| U10 | `zfa tdd run <feature>` fails fast on the first red engine step: no skin step, no skin receipt, exit 1. | US3.AC2 | DONE |
| U11 | a successful meta run appends the unified journal entry to `tdd/cycle-log.md` naming both receipts and prints the machine summary line `run: feature=... result=complete ...`. | US3.AC3 | DONE |
| U12 | the meta run on a legacy feature is byte-compatible with the pre-split driver (same steps, same summary, same exit code) plus the receipts and unified entry. | US3.AC4 | DONE |
| U13 | `zfa tdd status <feature>` prints one line with both lane verdicts and exits 0 iff both are green. | US4.AC1 | DONE |
| U14 | status names absent/red lanes honestly and exits non-zero. | US4.AC2 | DONE |
| U15 | lane resolution prefers the 04-ENGINE.md/04-SKIN.md plan files when present (ids in both files are BOTH lanes). | plan | DONE |
