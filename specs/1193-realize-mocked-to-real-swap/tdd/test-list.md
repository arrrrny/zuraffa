# Test list — spec 1193 realize MOCKED→REAL swap

## Engine loop:

| ID | description | FR | state |
| --- | --- | --- | --- |
| B-001 | Feature-mode resolution: `realize <feature> --adapter <name>` resolves specs/<feature>, the engine-receipt entity, and the certified mock; uncertified receipt methods block with the `zfa mock create <Entity> --certify` fix | FR-001 | DONE |
| B-002 | Adapter scaffold: missing adapter class → scaffolded behind the mock's `implements` clause with the interface's member signatures, hand-delta seam header, nuance ledger entry, and NO generation receipt | FR-002 | DONE |
| B-003 | Idempotent unregister-first swap: mock symbols out, adapter in; same-adapter re-run = already-real no-op (exit 0, zero new writes); already-swapped tree not re-swapped; domain files byte-identical | FR-003 | DONE |
| B-004 | Contract suite unchanged: baseline (mock) + real-binding runs; zero test-file byte edits; red real run rolls all rebinds back with attribution | FR-004 | DONE |
| B-005 | Differential gate: fixture drift beyond threshold blocks REAL (rollback, MOCKED era, manifest kept); manifest.json and mock-cert.* files are skipped, not runner-errors | FR-005 | DONE |
| B-006 | Ladder advance: run-state behaviors mocked→real→done; realize-state era REAL; era-tagged + unified journal entries; manifest retired → FeatureProvenanceReader derives complete(real) | FR-006 | DONE |
| B-007 | Swap receipt: realize.<feature>.<adapter>.receipt.json carries files, digests (re-derivable), gate outcome, ladder, generated/mock/hand ratios; parses as proof.v1 | FR-006 | DONE |
| B-008 | --dry-run prints the plan and writes nothing (no scaffold, no rebind, no state, no receipts, no manifest deletion) | FR-007 | DONE |
| B-009 | BehaviorState.real integrates: lane counts green tier; run-state round-trip; driver reconcile keeps a real claim only with green evidence | FR-008 | DONE |
| B-010 | 913 back-compat: the existing entity/behavior-target realize tests stay green (no behavior change on the legacy surface) | FR-004 | DONE |
