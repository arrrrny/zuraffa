# GitHub Issue

- URL: https://github.com/arrrrny/zuraffa/issues/1521
- Number: 1521
- Filed: 2026-09 (discovered while applying the review fixes for pool task `49472118-2123-43b6-adf0-8017256d4a22`; unrelated to those six findings, so left untouched to keep that change scoped)
- Title: regression: feature 1484 breaks the #1481 fatal unit-fallback tests (plan_command_bug_1481_test.dart is red on feat/1484-fr-manual-exemption)
- Severity: high (PR #1504 cannot go green while three tests assert a fallback class the feature no longer produces)

## Report (verbatim from the issue)

### Summary

`test/plugins/tdd/commands/plan_command_bug_1481_test.dart` is **red on the `feat/1484-fr-manual-exemption` branch** (PR #1504) — 3 of 8 tests fail at HEAD `b34adae2` / `ee9cc948`, before any of the review-fix changes.

The feature-1484 change routes an FR with **no surviving `traces:` binding** to a *manual declaration* instead of emitting a unit-lane fallback route. That makes the #1481 fixture (`_deadEndSpec`: two FRs, no `traces:`, no Layer Contracts section) produce **no unit route line at all** — only the new defaulted-FR warning — so the `[fallback: no declared trace — make will dead-end]` class and its one-line dead-end tally are never emitted.

### Command

```bash
dart test test/plugins/tdd/commands/plan_command_bug_1481_test.dart
```

Result at `b34adae2` (with the working tree clean): `+5 -3: Some tests failed.`

### Failing tests (group `#1481: the two fallback classes are distinguishable`)

1. **`a unit fallback renders the FATAL class (no declared trace, make will dead-end) while the scenario heals to declared`**
   - Expected: contains `route: U1 -> unit lane [fallback: no declared trace — make will dead-end`
   - Actual: only `zfa tdd plan: WARNING: FR-001 derives no unit behaviour — no surviving `traces:` binding … recorded as a manual declaration in tdd/traceability.md.`

2. **`a single summary line tallies the dead-end behaviors (no scanning 42 route lines)`**
   - Expected: contains `2 behaviors will dead-end at make — no declared contract trace (U1, U2)`
   - Actual: same defaulted-FR warning; no tally line.

3. **`the tally counts PLURAL dead-ends correctly`**
   - Expected: contains `3 behaviors will dead-end at make — no declared contract trace (U1, U2, U3)`
   - Actual: same defaulted-FR warning; no tally line.

### Root cause

- `ee9cc948` (feature 1484, "route inherently non-unit FRs out of the unit behaviour lane") introduced the default-to-manual routing for unbound FRs in `lib/src/plugins/tdd/commands/plan_command.dart`.
- `test/plugins/tdd/commands/plan_command_bug_1481_test.dart` (last touched by `903240d5`, the #1481 fix) still asserts the pre-1484 behaviour: a unit-lane `[fallback: no declared trace — make will dead-end]` route plus the dead-end tally.
- The follow-up commit `b34adae2` ("add traces bindings to the 5 fixtures the default-to-manual flip stranded") updated five *other* fixtures stranded by the same flip but did not touch this one.

### Impact

PR #1504 cannot be green while these three tests assert a fallback class that feature 1484 no longer produces. Either (a) the #1481 dead-end-tally expectations need updating to feature 1484's manual routing, or (b) a non-FR behavior class should still be reachable as a fatal unit fallback and the fixture should be rewritten to exercise it.
