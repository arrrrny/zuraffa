# Plan: 913-tdd-realize

- **Spec ID**: 913-tdd-realize
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
- Prepare a candidate mock → real rebind while `RunState.era` remains `MOCKED`; do not persist `REAL` during command setup
- Keep `BehaviorState` / `TestListReader._parseState` on `PENDING`, `RED`, `GREEN`, and `DONE`; retain `BASELINE`, `BLOCKED`, and `DROPPED` as bookkeeping states, never era values

### Phase 2: contract gate
- Establish a validated green mock baseline with the unchanged fixtures and harness before evaluating the real binding
- Run the MOCK-era test suite against the real binding (untouched tests)
- Apply deterministic fail-closed triage: `mock-baseline`, `fixture`, or `test-harness` failures block attribution; only a real-binding-only failure after those checks is `real-adapter`
- Must stay green for the swap to proceed

### Phase 3: differential gate
- Real vs mock run the same committed fixtures (reuses #832 simulate adapter infrastructure)
- Output diff = drift report with per-field comparison
- Threshold from `.zfa.json` (configurable)
- Reuses #805 differential machinery for diff computation
- If both gates pass, atomically append their successful REAL-era evidence and persist `RunState.era = REAL`; on either failure, persist neither the REAL era nor successful-transition evidence

### Phase 4: nuance receipts
- Hand-written deltas recorded in feature's provenance ledger
- Each entry: (file, reason, diff-hash)
- Hand-deltas legal; ungated hand-deltas blocked
- References #807 proof-carrying pattern

### Phase 5: era-tagged cycle-log
- Add an `era` field (`MOCKED` or `REAL`) to newly appended cycle-log entries; never rewrite or backfill existing entries
- Preserve every prior entry byte-for-byte and retain each new entry's command, failure output, green-making change/generation evidence, and refactor evidence for `/speckit.tdd.verify`
- Keep behavior and bookkeeping states independent from era metadata; the MOCKED → REAL run-era transition remains visible in append-only history

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
- `era_tagged_log_test.dart` — append-only writes preserve prior entries byte-for-byte and retain complete command, failure, green-making, and refactor evidence for both MOCKED and REAL eras

## Risks

- Mock-vs-real interface drift can silently fail the contract gate
- Differential threshold miscalibration → false positives / negatives
- Hand-delta reason metadata must be enforced (not optional)
- Era-tagged evidence must not bloat cycle-log unbounded
