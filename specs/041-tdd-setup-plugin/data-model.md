# Phase 1 — Data Model

## Entities

### Behavior
```dart
class Behavior {
  final String id;          // "A1" / "U3"
  final String feature;
  final BehaviorKind kind;  // acceptance | unit
  final String description;
  final String sourceCriterion;  // "AC-1" / "FR-013"
  final String target;
  BehaviorState state;      // pending | red | green | done
}
```

### TddProfile
Five-key command map: `runner`, `single`, `file`, `suite`, `coverage`.

### CycleLogEntry
```dart
class CycleLogEntry {
  final String behaviorId;
  final CycleEntryKind kind;  // red | green
  final String runnerCommand;
  final int exitCode;
  final String capturedOutput;
  final FailureClass? classification;  // assertionFailure | compileError | loadError | unexpectedGreen
}
```

### RunState
Per-feature resumable state at `tdd/run-state.json`.

## State machine

PENDING → (gen + verify-red) → RED → (make) → GREEN → (refactor) → DONE

## Invariants

- I-001: Every subcommand consults `TddProfile` from `tdd-profile.md`.
- I-002: No hand-written source in `make`.
- I-003: Cycle log is append-only.
- I-004: State file is mutable, test list is reproducible.
- I-005: Misfire-stop is non-negotiable.
