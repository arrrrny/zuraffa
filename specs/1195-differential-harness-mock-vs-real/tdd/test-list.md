# Test list — spec 1195 differential-harness-mock-vs-real

## Key Entities

| Entity | Fields |
| --- | --- |
| | |
| User | id:String, email:String |

## Harness loop:

| ID | description | FR | state |
| --- | --- | --- | --- |
| B-001 | Same-shape value drift on an entity field is NOT a divergence (parity is shape, not bytes) | SC-1 | DONE |
| B-002 | Entity-shape drift (missing field / type change) produces a NAMED row: fixture, field, dimension, clause, input, mockOutput, realOutput | SC-1/SC-2 | DONE |
| B-003 | State-transition field drift (value inequality) produces a row in the state-transition dimension | SC-1 | DONE |
| B-004 | Error-kind mismatch and one-sided error presence produce rows in the error-kind dimension | SC-1 | DONE |
| B-005 | Default verdict strict: any row is `divergence` (blocks); threshold from `.zfa.json` `tdd.realizeDifferentialThreshold` (0.0 default, inclusive boundary) | SC-2 | DONE |
| B-006 | Deterministic receipt: same fixtures + same outputs → byte-identical receipt on replay; the digest changes when a fixture changes | SC-3 | DONE |
| B-007 | Receipt is journal-consumable: schema `realize-diff-receipt.v1`, `journal.gate_state` (green/red/not_assessed), `journal.violations` (row ids), `journal.refs` | SC-4 | DONE |
| B-008 | No fixtures directory (or no .json files) → `skipped` (not_assessed), never a vacuous pass | SC-1 | DONE |
| B-009 | Driver failure / unparsable fixture → `runner-error`, the gate fails closed | SC-2 | DONE |
| B-010 | Fixture `clauses` map overrides the default clause attribution; fixture `contract` map pins exact-value parity | SC-1 | DONE |
| B-011 | `--diff-only` runs ONLY the differential: tree untouched, no realize-state.json, receipt mode `diff-only`, era-tagged `realize-diff` entry | SC-5 | DONE |
| B-012 | `--diff-only` divergence exits 1 with the named row on stdout; pass exits 0 with `differential=pass` | SC-5/SC-2 | DONE |
| B-013 | Embedded realize: divergence rolls the rebind back, prints the named row, blocks the MOCKED→REAL transition; rows within a consciously raised threshold pass but are still named | SC-2 | DONE |
