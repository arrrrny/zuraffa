# Test list — spec 1110 cert-gate-engine

## Key Entities

| Entity | Fields |
| --- | --- |
| | |
| Login | id:String |

## Engine loop:

| ID | description | FR | state |
| --- | --- | --- | --- |
| B-001 | CertRegistry existence: wired entity without a mock-cert receipt blocks with the exact cert command | FR-002 | DONE |
| B-002 | CertRegistry freshness: a receipt older than the entity source is stale and blocks | FR-002 | DONE |
| B-003 | CertRegistry corrupt/unsatisfied receipts block; unwired entities are not gated | FR-002 | DONE |
| B-004 | EngineGateReceipt writes engine.gate.<Entity>.refused.json with the {entity, reason, fix, refs} contract in both homes | FR-003 | DONE |
| B-005 | EngineChecker consults the registry: uncertified/stale CORE entity fails check with the refusal receipt path; fresh all-satisfied receipt passes | FR-005 | DONE |
| B-006 | run-engine preflight blocks on stale receipts and writes the feature-scoped refusal receipt; the gate heals when certified | FR-002 | DONE |
| B-007 | zfa tdd status renders the gate refusal fix and exits non-zero | FR-003 | DONE |
| B-008 | zfa mock create Login --fail emits <Entity>FailingMockProvider whose every method throws the sealed failure type | FR-001 | DONE |
| B-009 | make engine --fail records failure_mode: failing in engine.receipt.json | FR-001 | DONE |
| B-010 | mock create --certify routes the CLI flag into the sandbox certification (the receipt the gate requires) | FR-002 | DONE |
