# Test list — spec 1113 unified-tdd-journal

## Key Entities

| Entity | Fields |
| --- | --- |
| JournalEntry | feature, cycle, phase, started_at, finished_at, gate_state, receipts, violations, refs |

## Engine loop:

| ID | description | FR | state |
| --- | --- | --- | --- |
| J-001 | zfa tdd run 004-login-ui writes specs/<f>/tdd/journal.json (schema 1, feature, entries) beside the receipts | FR-001 | PENDING |
| J-002 | every journal entry is schema-valid: the 9 required fields, the cycle/phase/gate_state enums, the refs triple | FR-001 | PENDING |
| J-003 | the meta run journals one entry per terminal outcome: engine entry + skin entry (phase=drive) + meta entry (phase=aggregate, gate_state=green) | FR-003 | PENDING |
| J-004 | a fail-fast engine red journals the meta entry with gate_state=red and the stopped_at violation | FR-003 | PENDING |
| J-005 | the cert-gate preflight refusal journals gate_state=preflight_red (phase=gate) before any step spawns | FR-003 | PENDING |
| J-006 | run-engine / run-skin standalone runs append their own cycle entries (engine/skin, phase=drive) | FR-003 | PENDING |
| J-007 | journal.schema.json lands beside journal.json on first append and validates the written entries | FR-001 | PENDING |
| J-008 | JournalReader reads one canonical stream: entries, refs-followed receipts, cycle-log content, per-behavior green evidence | FR-002 | PENDING |
| J-009 | zfa tdd status prints the journal one-line verdict (engine ✅ d/t, skin ✅ d/t, mocks, violations) and exits 0 on green | FR-005 | PENDING |
| J-010 | zfa tdd prove exists: baseline prove on a green feature is clean (all gated, exit 0) and journals a prove entry | FR-004 | PENDING |
| J-011 | after editing ONE skin view, prove reports ONLY that behavior ungated (incremental delta, exit 1) | FR-004 | PENDING |
| J-012 | theater loads the journal through JournalReader (snapshot carries the journal entries + verdict) | FR-006 | PENDING |
