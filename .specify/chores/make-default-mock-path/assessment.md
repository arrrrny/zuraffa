# Chore Assessment: make default → mock path: MOCKED tier

- **Slug**: make-default-mock-path
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/909
- **Verdict**: in scope
- **Size**: large

## Report (verbatim or summarized)

> Part of #908 (Mock-First Realization). Current make default (func-stub) produces shallow green: `subject_u1() => 0` proves nothing. The legacy zik_zak already validated the architecture: 165 mock files, mock datasources behind interfaces, DI-swapped. `zfa mock create` already emits the full trio (mock data + datasource interface + mock datasource) — verified live. The TDD loop must route through it.
>
> Required: (1) `zfa tdd make` default path: `zfa mock create` for the behavior's entity/contract → wire mock datasource via DI → target test green against the MOCK. State: MOCKED. (2) run-state gains the MOCKED tier between green-real and done; suite-green at MOCKED = contract conformance. (3) func-stub path demoted to explicit `--stub` escape hatch; cycle-log marks stub-era evidence distinctly so verify can reject stub-only green from counting as contract-proven. (4) Fixture provenance: mock-data hashes bound into cycle-log evidence.

## Summary

This chore routes the `zfa tdd make` default generation path through `zfa mock create` (which already emits mock data + datasource interface + mock datasource) instead of the current `zfa tdd func` (which produces shallow `subject() => 0` stubs). It adds a MOCKED tier to the behavior state machine between GREEN and DONE, demotes func-stub to a `--stub` escape hatch, and requires fixture provenance in cycle-log evidence. This is the P0 foundation of the Mock-First Realization epic (#908).

## Constitution Check

No `.specify/constitution.md` was found. However, the project's AGENTS.md establishes hard rules:
- "Every Dart file in `apps/zikzak_demo` must come from a `zfa` command" — this chore makes the TDD loop produce meaningful (mock-backed) code instead of stubs, which aligns with the "generated code is real code" principle.
- "Do not hand-write code to route around a zfa misfire" — routing through `zfa mock create` (an existing, tested command) is the correct approach.
- The generation planner (`lib/src/plugins/tdd/services/generation_planner.dart`) already maps behaviors to `zfa tdd func` / `zfa make` / `zfa entity create` — adding `zfa mock create` as a new route is architecturally consistent.

## Affected Paths

- `lib/src/plugins/tdd/models/behavior.dart:30` — `BehaviorState` enum needs `mocked` value added between `green` and `done`
- `lib/src/plugins/tdd/models/run_state.dart:56-57` — `RunState.toJson()` serializes behavior states via `state.name`; new `mocked` value must serialize/deserialize correctly
- `lib/src/plugins/tdd/services/run_state_store.dart` — validates run-state JSON; must accept `mocked` as a valid state
- `lib/src/plugins/tdd/services/generation_planner.dart:10-50` — planner maps behaviors to generation steps; the default path for entity/CRUD behaviors must route to `zfa mock create` instead of `zfa tdd func`
- `lib/src/plugins/tdd/commands/make_command.dart:1-100` — make command orchestrates generation; must support mock-create as the default path and func-stub as `--stub`
- `lib/src/plugins/tdd/commands/run_command.dart:1-80` — run driver must support MOCKED tier transitions
- `lib/src/plugins/tdd/services/cycle_log.dart` — cycle-log evidence must include mock-data hashes (fixture provenance)
- `lib/src/commands/mock_command.dart:62-80` — `DataMockCommand` (the `zfa mock create` surface) already works; this is the existing command the new path routes through
- `lib/src/plugins/mock/capabilities/create_mock_capability.dart:6-73` — `CreateMockCapability` already emits mock data + datasource interface + mock datasource
- `test/plugins/mock/create_mock_capability_test.dart` — existing tests for mock creation

## Proposed Approach

**Preferred**:

1. **Add MOCKED to BehaviorState** (`behavior.dart`): Insert `mocked` between `green` and `done` in the enum. Update `RunState.toJson()`/`fromJson()` to handle the new value. Verify backward compatibility with existing run-state.json files on disk (the `BehaviorState.values.byName()` call in `RunState.fromJson` will fail on unknown values — add a guard or migration).

2. **Route generation planner through mock-create** (`generation_planner.dart`): For entity-bearing and CRUD behaviors, change the default plan from `zfa tdd func <id>` to `zfa mock create --name <Entity>`. The plan becomes: `zfa mock create --name <Entity>` → `zfa build` (instead of `zfa tdd func <id>` → `zfa build`). Add `--stub` flag to the planner that falls back to the func-stub path.

3. **Update make command** (`make_command.dart`): Accept `--stub` flag. When set, use the legacy func-stub path. When not set, use the mock-create path. The `--stub` path marks cycle-log evidence as stub-era (distinct from mock-era evidence).

4. **Wire mock datasource via DI** (`wire_command.dart` or `make_command.dart`): After `zfa mock create` generates the mock data + interface + mock datasource, the wire step must register the mock datasource in the DI container so the test subject resolves the mock, not the real adapter.

5. **MOCKED state transitions** (`run_command.dart`): After make produces green against the mock, the behavior transitions to MOCKED (not DONE). The run driver recognizes MOCKED as a valid intermediate state. DONE is only reachable after the realization ladder (mock→real swap + differential gate + receipting).

6. **Fixture provenance** (`cycle_log.dart`): Include mock-data file hashes in the green-evidence entry for MOCKED-tier green. The existing `FixtureRegistry.sha256Hex()` can be reused.

**Alternatives**:
- **Parallel paths**: Keep func-stub as default and add `--mock` flag instead — less disruptive but defeats the "mock is the default" principle.
- **Generation planner extension only**: Route through mock-create only in the generation planner, not in the make command's direct invocation — keeps the make command unchanged but makes the flag behavior inconsistent.

**Paths likely to change**:
- `lib/src/plugins/tdd/models/behavior.dart`
- `lib/src/plugins/tdd/models/run_state.dart`
- `lib/src/plugins/tdd/services/run_state_store.dart`
- `lib/src/plugins/tdd/services/generation_planner.dart`
- `lib/src/plugins/tdd/commands/make_command.dart`
- `lib/src/plugins/tdd/commands/run_command.dart`
- `lib/src/plugins/tdd/services/cycle_log.dart`

**Verification to run**:
- `dart test test/plugins/tdd/make_command_test.dart` — existing make tests must pass with mock-default
- `dart test test/plugins/tdd/run_command_test.dart` — run driver must handle MOCKED state
- `dart test test/plugins/tdd/models/run_state_test.dart` — run-state serialization with mocked value
- `dart test test/plugins/mock/create_mock_capability_test.dart` — mock creation still works
- `dart test test/plugins/tdd/services/run_state_store_test.dart` — run-state store accepts mocked
- `dart analyze` on all changed files

## Risks & Considerations

- **Backward compatibility**: Existing run-state.json files with `{ pending, red, green, done }` will not have `mocked`. The `RunState.fromJson` uses `BehaviorState.values.byName(v)` which will throw `ArgumentError` on an unknown value. Need to either (a) default unknown states to `pending` with a warning, or (b) add a migration step.
- **DI wiring complexity**: The mock-create path generates the mock datasource but wiring it into the DI container for the test subject is non-trivial — the wire command must know which mock to bind.
- **Performance**: `zfa mock create` + `zfa build` may be slower than `zfa tdd func` + `zfa build` — the mock path generates more files.
- **Stub escape hatch semantics**: When `--stub` is used, the cycle-log must clearly mark evidence as stub-era so `verify` can reject it from counting as contract-proven. This requires a new evidence marker format.
- **Size**: This is a large change touching the state machine, generation planner, make command, run driver, and cycle-log — multiple integration points that must be coordinated.

## Open Questions

- [NEEDS CLARIFICATION: Should the `--stub` flag be on `zfa tdd make` or on `zfa tdd run` (or both)?]
- [NEEDS CLARIFICATION: How does the wire step know which mock datasource to bind for a given behavior? From the entity name in the behavior description, or from a separate configuration?]
- [NEEDS CLARIFICATION: Is the MOCKED state serialized as `"mocked"` in run-state.json, and how are existing files with only {pending,red,green,done} handled?]
- [NEEDS CLARIFICATION: Should fixture provenance (mock-data hashes) be mandatory for MOCKED-tier green, or optional with a warning?]
