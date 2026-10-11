---
feature: 1468-behavior-state-forward-compat
loop: inside-out
profile: .specify/memory/tdd-profile.md
spec_criteria: 5
planned_at: 94048e31
updated_at: 94048e31
suite_baseline: green
---

# Test List: BehaviorState forward-compatibility (degrade unknown states to pending)

Pure deserialization work in `RunStateStore._validated()` — no user-visible
entry point beyond `store.load()`, so the loop is inside-out: every behavior
is a unit behavior on the store. One behavior per line, traced to the spec's
success criteria.

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/services/run_state_store.dart` (`_validated()`)

| id | behavior                                                                                     | traces | kind    | state    | test                                                                                     |
| --- | ------------------------------------------------------------------------------------------- | ------ | -------- | ---- | ---------------------------------------------------------------------------------------- |
| U1  | An unknown state name degrades that entry to `pending` and `load()` succeeds                 | SC-1   | example | DONE    | `test/plugins/tdd/services/run_state_store_test.dart::degrades unknown state to pending` |
| U2  | A warning naming the unknown state, the behavior id, and the fallback is logged to stderr    | SC-2   | example | DONE    | `test/plugins/tdd/services/run_state_store_test.dart::warns with the degrade receipt`    |
| U3  | A mixed map keeps known values and degrades only unknown ones (downgraded-binary resumability) | SC-3 | example | DONE    | `test/plugins/tdd/services/run_state_store_test.dart::mixed map keeps known degrades unknown` |
| U4  | An all-known map loads with every value unchanged (backwards compatible)                     | SC-4   | example | DONE    | `test/plugins/tdd/services/run_state_store_test.dart::all-known state loads unchanged`   |
| U5  | A non-string state VALUE stays corruption (only unknown NAMES degrade)                       | SC-5   | example | DONE    | `test/plugins/tdd/services/run_state_store_test.dart::non-string state value is still corruption` |

### `test/plugins/tdd/services/run_state_store_test.dart` (legacy contract retention)

| id | behavior                                                                        | traces | kind             | state    | test                                                        |
| --- | ------------------------------------------------------------------------------ | ------ | ----------------- | ---- | ----------------------------------------------------------- |
| B1  | Legacy shape violations (non-object states, wrong feature, unknown step) still corrupt | SC-5   | characterization | DONE    | existing `U9: shape violations are corruption, not crashes` |
| B2  | The `{"B-1": "blue"}` corruption row is retired — unknown NAMES are no longer corruption | SC-1   | characterization | DONE    | amended `U9` (row removed; owned by U1/U3)                  |

## Invariants and edge cases still to place

- None outstanding: `RunState.fromJson` (model-side `byName`) is explicitly
  out of scope per the spec's single-point constraint; `in_flight_step`
  whitelist is untouched.
