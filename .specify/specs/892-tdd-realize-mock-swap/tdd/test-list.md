# Test List: 892-tdd-realize-mock-swap (spec 913 — zfa tdd realize)

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`. Each stays red until the feature works
end to end through its real entry point (`zfa tdd realize <entity|behavior>
--adapter <real>` driven through `CliRunner`).

| id  | behavior                                                                                    | traces | kind      | state   | test                                                                  |
| --- | ------------------------------------------------------------------------------------------- | ------ | --------- | ------- | -------------------------------------------------------------------- |
| A1  | `zfa tdd realize` rebinds DI mock→real behind the same interface, both gates pass, era transitions MOCKED→REAL, era-tagged evidence lands in cycle-log | SC-1, SC-4, SC-5 | example | PENDING | `test/plugins/tdd/commands/realize_command_test.dart::A1 full swap green path` |
| A2  | `--adapter` is required and single (a swap without a named real adapter is refused, not guessed) | CC-1   | example   | PENDING | `test/plugins/tdd/commands/realize_command_test.dart::A2 adapter required` |
| A3  | A red MOCK-era suite against the real binding blocks the swap, rolls the rebind back, and the verdict names which side broke the contract | SC-1   | example   | PENDING | `test/plugins/tdd/commands/realize_command_test.dart::A3 red contract gate blocks + rolls back` |
| A4  | Differential drift beyond the `.zfa.json` threshold blocks the transition; within threshold it passes with a drift report | SC-2   | example   | PENDING | `test/plugins/tdd/commands/realize_command_test.dart::A4 differential gate threshold` |
| A5  | Ungated hand-deltas block the swap; deltas gated with `--hand-delta <file> --reason <text>` are recorded (file, reason, diff-hash) and the swap proceeds | SC-3   | example   | PENDING | `test/plugins/tdd/commands/realize_command_test.dart::A5 hand-delta gate` |
| A6  | A behavior id (not an entity name) resolves through the registry to the same realization path | CC-1   | example   | PENDING | `test/plugins/tdd/commands/realize_command_test.dart::A6 behavior id target` |

## Inner loop: unit behaviors

Grouped by the component from `plan.md` that owns them. Each line names one
observable result.

### `lib/src/plugins/tdd/services/realize_state.dart`

| id  | behavior                                                              | traces | kind     | state   | test                                                          |
| --- | --------------------------------------------------------------------- | ------ | -------- | ------- | ------------------------------------------------------------ |
| U1  | Absent state file means era MOCKED — mock-first is the default path, never an exception | SC-5   | example  | PENDING | `test/plugins/tdd/services/realize_state_test.dart::U1`      |
| U2  | transitionToReal persists `tdd/realize-state.json` with era REAL and an append-only transition history carrying gate evidence | SC-4   | example  | PENDING | `test/plugins/tdd/services/realize_state_test.dart::U2`      |
| U3  | A second realize of the same adapter is idempotent — no duplicate transition, era stays REAL | SC-4   | example  | PENDING | `test/plugins/tdd/services/realize_state_test.dart::U3`      |

### `lib/src/plugins/tdd/services/di_rebind.dart`

| id  | behavior                                                              | traces | kind     | state   | test                                                          |
| --- | --------------------------------------------------------------------- | ------ | -------- | ------- | ------------------------------------------------------------ |
| U4  | scan finds the GetIt-style mock binding sites for an entity in lib/     | CC-1   | example  | PENDING | `test/plugins/tdd/services/di_rebind_test.dart::U4`          |
| U5  | rebind swaps `XMockDataSource`→`<Adapter>` at binding sites only, drops the mock import, adds the adapter import, and never touches `domain/` (same generated interface) | CC-1, SC-1 | example | PENDING | `test/plugins/tdd/services/di_rebind_test.dart::U5`   |
| U6  | rebind refuses when no file in lib/ declares the adapter class — no auto-generation of real implementations | CC-1 (out-of-scope guard) | example | PENDING | `test/plugins/tdd/services/di_rebind_test.dart::U6` |
| U7  | rebind refuses when there is no mock binding to swap (not a mock-era project) | CC-1   | example  | PENDING | `test/plugins/tdd/services/di_rebind_test.dart::U7`          |

### `lib/src/plugins/tdd/services/contract_gate.dart`

| id  | behavior                                                              | traces | kind     | state   | test                                                          |
| --- | --------------------------------------------------------------------- | ------ | -------- | ------- | ------------------------------------------------------------ |
| U8  | green verdict when the mock-era suite is green against both bindings    | SC-1   | example  | PENDING | `test/plugins/tdd/services/contract_gate_test.dart::U8`      |
| U9  | verdict `real-broke-contract` when the baseline (mock) run is green and the real run is red | SC-1   | example  | PENDING | `test/plugins/tdd/services/contract_gate_test.dart::U9`      |
| U10 | verdict `mock-broke-contract` when the baseline (mock) run is already red — the mock era broke it, not the real impl | SC-1   | example  | DONE | `test/plugins/tdd/services/contract_gate_test.dart::U10`     |

### `lib/src/plugins/tdd/services/differential_gate.dart`

| id  | behavior                                                              | traces | kind     | state   | test                                                          |
| --- | --------------------------------------------------------------------- | ------ | -------- | ------- | ------------------------------------------------------------ |
| U11 | real vs mock outputs on the same committed fixtures produce a per-field drift report (reuses #805-style findings) | SC-2   | example  | DONE | `test/plugins/tdd/services/differential_gate_test.dart::U11` |
| U12 | threshold comes from `.zfa.json` (`tdd.realizeDifferentialThreshold`); default is 0.0 (strict) and drift above it fails the gate | SC-2   | example  | DONE | `test/plugins/tdd/services/differential_gate_test.dart::U12` |
| U13 | a missing fixtures directory is reported `skipped`, never silently passed | SC-2   | example  | DONE | `test/plugins/tdd/services/differential_gate_test.dart::U13` |

### `lib/src/plugins/tdd/services/nuance_receipts.dart`

| id  | behavior                                                              | traces | kind     | state   | test                                                          |
| --- | --------------------------------------------------------------------- | ------ | -------- | ------- | ------------------------------------------------------------ |
| U14 | record() writes (file, reason, diff-hash) into `tdd/provenance-ledger.json` (#807 proof-carrying pattern) | SC-3   | example  | DONE | `test/plugins/tdd/services/nuance_receipts_test.dart::U14`   |
| U15 | record() refuses an empty reason — reason metadata is enforced, not optional | SC-3   | example  | DONE | `test/plugins/tdd/services/nuance_receipts_test.dart::U15`   |
| U16 | detect() finds hand-deltas as files whose bytes drifted from their last receipted/ledger digest, and flags unreceipted files | SC-3   | example  | DONE | `test/plugins/tdd/services/nuance_receipts_test.dart::U16`   |

### `lib/src/plugins/tdd/services/era_tagged_log.dart`

| id  | behavior                                                              | traces | kind     | state   | test                                                          |
| --- | --------------------------------------------------------------------- | ------ | -------- | ------- | ------------------------------------------------------------ |
| U17 | appended entries carry `- era: MOCKED|REAL` and the schema-1 hash chain (prev-hash/hash) over an era-aware payload | SC-4   | example  | PENDING | `test/plugins/tdd/services/era_tagged_log_test.dart::U17`    |
| U18 | the last era tag is read back from the cycle log and survives across appended entries (evidence per era) | SC-4   | example  | PENDING | `test/plugins/tdd/services/era_tagged_log_test.dart::U18`    |

## Traceability

- SC-1..SC-5 are the spec.md "Success criteria"; CC-1..CC-5 are the five
  command-contract clauses. A1/A3/A4/A5 carry the end-to-end proof; U1-U18 pin
  each service's own contract so the acceptance tests are not the only guard.
