# 1468-behavior-state-forward-compat

- **Spec ID**: 1468-behavior-state-forward-compat
- **Created**: 2026-09-11
- **Source**: GitHub issue #1468 (SPEC 1468 — BehaviorState forward-compatibility)
- **Type**: bug/feature (P2 — Medium, forward-compatibility, not a crash)
- **Branch**: feat/1468-behavior-state-forward-compat

## Problem

`RunStateStore._validated()` refuses to load `tdd/run-state.json` when the
`behavior_states` map contains a state name the current binary does not know.
A newer zfa binary that introduces a state value (or any hand edit) produces a
state file an older binary cannot read at all: the enum-check loop in
`_validated()` maps every unknown name to `RunStateCorruptException`, and the
model-side `RunState.fromJson` (`BehaviorState.values.byName`) throws a bare
`StateError` with no fallback. Binary version skew therefore breaks
resumability: a downgraded zfa binary (e.g. v6.1.x reading state written by
v6.2.x) cannot read a state file it should be able to resume from.

## Goal

`RunStateStore._validated()` gracefully degrades unknown `BehaviorState`
values to `BehaviorState.pending` with a warning, instead of throwing — a
downgraded binary reads the state file, keeps every known state, and resumes.

## Success criteria (measurable)

- **SC-1**: When `behavior_states` in `run-state.json` contains a state name
  not in `BehaviorState.values`, `RunStateStore.load()` succeeds and degrades
  that entry to `BehaviorState.pending` instead of throwing.
- **SC-2**: A warning naming the unknown state and the fallback is logged:
  `[run-state] unknown state "xyz" for behavior "B1" → degraded to pending`.
- **SC-3**: A downgraded zfa binary reading a state file produced by a newer
  one succeeds: unknown states become `pending`, known states retain their
  value (mixed maps verified).
- **SC-4**: Existing state files whose values are all known load completely
  unchanged (backwards compatible).
- **SC-5**: The state machine contract
  (`pending → blocked → red → green → mocked → done`) is unaffected — only
  deserialization of unknown names changes, not transitions; shape violations
  that are not state-name lookups (non-object `behavior_states`, non-string
  values, wrong `feature`, unknown `in_flight_step`) remain corruption.

## Hard constraints

- Fix ONLY the `_validated()` deserialization for-loop in
  `run_state_store.dart` — do NOT change the `BehaviorState` enum values,
  state machine transitions, or run driver logic.
- Single-point fix (the for loop in `_validated()`), not a refactor of the
  state store.
- Must pass `dart analyze` with no new warnings.

## Out of scope

- `RunState.fromJson` model-side deserialization (separate surface, same
  root pattern; untouched per the single-point constraint).
- State machine transitions, run driver logic, `in_flight_step` validation.
- Any migration or rewrite of existing state files.

## References

- #1468 (GitHub issue)
- spec 049-tdd-run (run-state.json contract, FR-004/FR-006 / U7-U11)
- bug #828 (fsync'd writes — the durability neighbor of this file)
