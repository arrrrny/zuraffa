# Plan: 892-tdd-realize-mock-swap

- **Spec ID**: 892-tdd-realize-mock-swap
- **Created**: 2026-09-03

## Architecture

```
┌─────────────┐    zfa tdd realize     ┌─────────────────┐
│  MOCK-era   │  --adapter <real> ──▶  │   REAL-era      │
│  datasource │                         │   adapter       │
│  + suite    │   CONTRACT GATE        │   + suite       │
│             │ ◀──────────────────▶   │   (same test)   │
│             │   DIFFERENTIAL GATE    │                 │
│             │ ◀──── fixtures ────▶   │                 │
│             │   NUANCE RECEIPTS      │                 │
│             │   provenance ledger    │                 │
└─────────────┘                         └─────────────────┘
       │                                       │
       └─────── cycle-log with era tag ────────┘
```

## Phases

### Phase 1: command skeleton
- `zfa tdd realize <entity|behavior> --adapter <real>` subcommand
- DI rebinding: mock → real via generated interface (no contract change)
- State transition MOCKED → REAL persisted in run-state

### Phase 2: contract gate
- Run the MOCK-era test suite against the real binding (untouched tests)
- Any red = verdict attributes failure to real impl OR mock contract breakage
- Must stay green for the swap to proceed

### Phase 3: differential gate
- Real vs mock run the same committed fixtures (reuses #832 simulate adapter infrastructure)
- Output diff = drift report with per-field comparison
- Threshold from `.zfa.json` (configurable)
- Reuses #805 differential machinery for diff computation

### Phase 4: nuance receipts
- Hand-written deltas recorded in feature's provenance ledger
- Each entry: (file, reason, diff-hash)
- Hand-deltas legal; ungated hand-deltas blocked
- References #807 proof-carrying pattern

### Phase 5: era-tagged cycle-log
- cycle-log entries carry era tag (MOCKED or REAL)
- Evidence preserved per era
- State transitions visible in history

## Files likely to change

- `lib/src/plugins/tdd/commands/realize_command.dart` (new)
- `lib/src/plugins/tdd/services/contract_gate.dart` (new)
- `lib/src/plugins/tdd/services/differential_gate.dart` (extends #805)
- `lib/src/plugins/tdd/services/nuance_receipts.dart` (new)
- `lib/src/plugins/tdd/services/era_tagged_log.dart` (new)
- `.specify/extensions/tdd/templates/realize.md` (new — command docs)

## Tests

- `realize_command_test.dart` — DI rebind, state transition
- `contract_gate_test.dart` — mock-era suite against real binding stays green
- `differential_gate_test.dart` — drift report, threshold enforcement
- `nuance_receipts_test.dart` — hand-deltas recorded with reason + diff-hash
- `era_tagged_log_test.dart` — era tag preserved through cycle-log

## Risks

- Mock-vs-real interface drift can silently fail the contract gate
- Differential threshold miscalibration → false positives / negatives
- Hand-delta reason metadata must be enforced (not optional)
- Era-tagged evidence must not bloat cycle-log unbounded
