# Tasks: 1468-behavior-state-forward-compat

- **Spec ID**: 1468-behavior-state-forward-compat
- **Created**: 2026-09-11

Dependency order: T001 (red tests) → T002 (fix) → T003 (legacy amendment)
→ T004 (verify + evidence). T001 and T003 both predate T002's green run in
evidence terms; T003's edit is committed with the red phase so the suite's
expectations match the spec before the fix lands.

## T001: Red tests — degrade-on-unknown behaviors
- Add tests to `test/plugins/tdd/services/run_state_store_test.dart`:
  - U1: unknown state name (`shelved`) in `behavior_states` → `load()`
    succeeds, entry is `BehaviorState.pending` (SC-1)
  - U2: warning `[run-state] unknown state "shelved" for behavior "B-001"
    → degraded to pending` on stderr, captured via `IOOverrides.runZoned`
    (SC-2)
  - U3: mixed map — known states (`done`, `red`) retain values, unknown
    (`archived`) becomes `pending` (SC-3, downgraded-binary resumability)
  - U4: all-known map loads with values unchanged (SC-4)
  - U5: non-string value (`"behavior_states": {"B-1": 7}`) still raises
    `RunStateCorruptException` (SC-5)
- Run the file → RED (evidence: `tdd/red-1468.log`)
- Tests: `run_state_store_test.dart`

## T002: Green — single-point fix in `_validated()`
- `lib/src/plugins/tdd/services/run_state_store.dart`, the
  `for (final key in statesMap.keys)` loop only:
  - unknown name → `stderr.writeln('[run-state] unknown state "$value" for
    behavior "$key" → degraded to pending')` and
    `states[key] = BehaviorState.pending`
  - remove the `corrupt('unknown behavior state …')` branch for state
    names; keep the non-string-value `corrupt` guard
- No other lib/ file changes; no enum/transition/driver changes
- Tests: `run_state_store_test.dart` (T001 set turns green)

## T003: Amend legacy U9 corruption case (spec-mandated drift)
- In `U9: shape violations are corruption, not crashes`, remove the
  `{"B-1": "blue"}` row — an unknown state NAME is no longer corruption
  (SC-1 contradicts it); it is covered by U1/U3
- Keep the remaining shape violations (non-object states, wrong feature,
  unknown `in_flight_step`)
- Tests: `run_state_store_test.dart`

## T004: Verification + evidence (non-behavioural)
- `dart analyze` changed files — no new issues vs baseline (0 errors /
  0 warnings / 112 pre-existing infos)
- `dart test test/plugins/tdd/services/run_state_store_test.dart` — full
  pass, report actual counts
- Mutation evidence: revert degrade branch → T001 tests fail (mutant
  killed) → restore → green
- `dart format .` → zero diffs
- Write `tdd/verification.md` with gates table + red/green/mutation logs
