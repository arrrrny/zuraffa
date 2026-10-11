# Test list — spec 1119 usecase verify / explain / drift gate / certify

## Key Entities

| Entity | Fields |
| --- | --- |
| Product | id:String |
| Task | id:String |

## Verify gate (`zfa usecase verify`):

| ID | description | FR | state |
| --- | --- | --- | --- |
| B-001 | fresh create → verify exits 0, every method conformant, envelope verdict pass | SC-1 | DONE |
| B-002 | tampered execute signature → verify exits 1 with `--> fix:` line naming the mismatch | SC-1 | DONE |
| B-003 | deleted method from a usecase file → verify exits 1 with missing_method + fix | SC-1 | DONE |
| B-004 | deleted usecase file → verify exits 1 with missing_file + fix | SC-1 | DONE |
| B-005 | verify --json emits ONE canonical zuraffa.verdict.v1 envelope as the LAST stdout line; findings carry machine-stable kinds | SC-1 | DONE |
| B-006 | verify without an entity is a usage error (exit 2) | SC-1 | DONE |
| B-007 | verify with no receipt still gates via conventional file discovery (receiptBound: false, honest details) | SC-4 | DONE |

## Drift gate (entity hash vs receipt):

| ID | description | FR | state |
| --- | --- | --- | --- |
| B-010 | entity source edited after create → verify exits 1 with entity_drift finding naming the receipt binding | SC-4 | DONE |
| B-011 | entity source deleted after create → verify exits 1 with entity_drift | SC-4 | DONE |
| B-012 | untouched entity → no drift verdict (verify exit reflects conformance only) | SC-4 | DONE |

## Certify + explain (`zfa usecase create --certify / --explain`):

| ID | description | FR | state |
| --- | --- | --- | --- |
| B-020 | create --certify on conformant output exits 0 and states the certification | SC-2 | DONE |
| B-021 | pre-tampered surface + create --certify (idempotent re-run) exits 1 with the conformance fix line; run is honest about generation success vs verify failure | SC-2 | DONE |
| B-022 | create --certify --json: envelope verdict flips to fail with findings when the gate fails; pass otherwise | SC-2 | DONE |
| B-023 | certified create receipt records the certification outcome | SC-2 | DONE |
| B-024 | create --explain (human) prints the block: per method class, variant (Future/Stream/Future<void>), result type, exception type | SC-3 | DONE |
| B-025 | create --explain --json carries the additive explain block; base envelope keys unchanged | SC-3 | DONE |
| B-026 | per-method verdict shape unchanged (name/action/reason only) with --certify --explain — extend, never break | SC-5 | DONE |
