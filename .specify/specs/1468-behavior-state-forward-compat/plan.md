# Plan: 1468-behavior-state-forward-compat

- **Spec ID**: 1468-behavior-state-forward-compat
- **Created**: 2026-09-11

## Technical Context

- **Subject**: `RunStateStore._validated()` — the top-level decode/validate
  helper in `lib/src/plugins/tdd/services/run_state_store.dart` that
  `load()` runs on every `tdd/run-state.json` read.
- **Enum**: `BehaviorState { pending, blocked, red, green, mocked, done }`
  (`lib/src/plugins/tdd/models/behavior.dart`) — the per-behavior cycle
  state the run driver advances through.
- **Serialization surface**: `run-state.json` — `behavior_states` is a
  JSON object mapping behavior id → state NAME (string). Writers store
  `v.name` (`save()`, `RunState.toJson`); the store's `_validated()` loop
  resolves each name back to the enum with a
  `BehaviorState.values.where((s) => s.name == value).firstOrNull` check
  and calls `corrupt('unknown behavior state "$value"')` on a miss —
  the failure this spec removes.
- **Language/SDK**: Dart 3.13.3 (stable), pure-Dart package (no Flutter
  needed for this surface). Tests: `package:test`, patterned on
  `test/plugins/tdd/services/run_state_store_test.dart` (U7–U11,
  `Directory.systemTemp` fixtures, `addTearDown` deletion).
- **Warning channel**: the tdd plugin's established convention is a direct
  `stderr.writeln(...)` for service-level warnings (see
  `test_list_reader.dart` deprecation warning); `RunStateStore` has no
  injected logger and the single-point constraint forbids adding one.

## Architecture

```
 run-state.json (newer binary)
   behavior_states: { "B1": "shelved", "B2": "done" }
        │
        ▼
 RunStateStore.load()  ──▶  _validated(raw, path, expectedFeature)
        │                          │
        │            for (key in statesMap.keys):
        │              value not a String      → corrupt (UNCHANGED, SC-5)
        │              name KNOWN              → enum value (UNCHANGED, SC-4)
        │              name UNKNOWN  ──────────▶ stderr warning + pending
        │                          │              (the ONLY new branch)
        ▼                          ▼
   resumable RunState ◀── Map.unmodifiable(states)
```

Single new branch inside the existing for-loop; every other validation
(feature match, JSON shape, non-string values, `in_flight_step` whitelist)
keeps its corrupt-on-fail contract.

## Phases

### Phase 1: red tests (test-first)

- Extend `test/plugins/tdd/services/run_state_store_test.dart` with the
  degrade behaviors (U1–U5 below): unknown name → `pending`, warning text,
  mixed known/unknown map, all-known untouched, non-string value still
  corrupt.
- Run → record RED evidence in `tdd/red-1468.log` (the unknown-name case
  currently throws `RunStateCorruptException`).

### Phase 2: green (single-point fix)

- In `_validated()`'s for loop only: on an unknown name, log
  `[run-state] unknown state "<name>" for behavior "<id>" → degraded to
  pending` to stderr and store `BehaviorState.pending` instead of calling
  `corrupt(...)`.
- No other file in `lib/` changes.

### Phase 3: legacy-test amendment (spec-mandated drift)

- `U9: shape violations are corruption` currently lists
  `{"B-1": "blue"}` as corruption — directly contradicted by SC-1. Move
  that case out of the corruption list; the degradation tests own it now.
  All other shape violations stay.

### Phase 4: verification (non-behavioural)

- `dart analyze` on changed files: no new issues vs the 112-issue baseline
  (0 errors / 0 warnings).
- `dart test` the changed test file: full pass.
- Mutation evidence: revert the degrade branch → new tests fail (mutant
  killed); restore → green. Recorded in `tdd/verification.md`.
- `dart format .` → zero diffs.
