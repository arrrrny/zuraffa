# Traceability: 0996-receipts-standalone-capabilities

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:cfc53487f424ad8ba205f68c3d2aa0075c174fbfd01898d8fafafd0c68bc2e43
statements: 5
automated: 5
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| FR-001 | 12 | FR-001: The system MUST auto-persist a `proof.v1` receipt after every successful | B-001 | automated |
| FR-002 | 17 | FR-002: Receipts MUST be emitted for: `di create`, `cache adapter`, | B-003 | automated |
| FR-003 | 22 | FR-003: Receipts MUST be machine-readable with the schema | B-002 | automated |
| FR-004 | 25 | FR-004: `zfa proof check` on a standalone receipt MUST validate: exit 0 with | B-005 | automated |
| FR-005 | 28 | FR-005: `zfa tdd verify` (the audit step) MUST include receipt-checking as a | B-004 | automated |

