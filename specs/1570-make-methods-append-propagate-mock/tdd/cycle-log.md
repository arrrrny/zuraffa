# Cycle Log: 1570-make-methods-append-propagate-mock

Append-only. One entry per red→green cycle.

---

## Cycle 1 — A1/A4/U3: drifted mock repaired instead of skipped (RED recorded)

**Date**: 2026-09-14 · **Branch**: `feat/1570-make-methods-append-propagate-mock`

Command:

```bash
rm -rf .dart_tool/test/ && dart test test/plugins/mock/mock_datasource_builder_1570_test.dart
```

Result: `+6 -5` — the five behavior tests FAIL on the pre-fix tree, the
six unchanged-behavior guards PASS (A2 in-sync skip, A3 fail-open ×2,
U4 revert/append/force precedence ×3).

Red evidence (verbatim failure summaries):

- A1 shape drift → `Expected: 'updated' Actual: 'skipped'` — the
  existence-based skip leaves the drifted mock untouched (the #1570
  bug).
- A1 through `MockPlugin.generate` → `the drifted mock must appear as
  repaired in the ledger: Expected: non-empty, Actual: []` — the
  plugin entry reports nothing (ledger honesty gap).
- A4 notice → the repair notice is absent from captured stdout
  (notice not implemented).
- A4 dry-run → `Expected: not 'skipped' Actual: 'skipped'` — the
  ledger hides the would-be repair in dry-run mode.
- U3 invented surface → `Expected: contains 'getList' Actual:
  Set:['get']` — no repair ran, the mock stays one member short of the
  interface (the compile error the build gate reports).

GREEN implementation (same cycle): new
`lib/src/plugins/mock/services/mock_staleness_detector.dart`
(shape-check staleness via `MethodExtractor.extractMethodsFromInterface`
+ `AstHelper`, fail-open on missing/unparseable interface surface) and
the wiring in `generateMockDataSource` (arm on the exact skip
condition; repair = existing idempotent append path + missing-member
impls synthesized from the interface's `ParsedUseCaseInfo` shapes;
honest notice; ledger `updated`).

**State**: RED recorded → implementation landed → same-cycle green run
below.

### Cycle 1 GREEN evidence

Command:

```bash
rm -rf .dart_tool/test/ && dart test test/plugins/mock/mock_datasource_builder_1570_test.dart
```

Result: `All tests passed!` — 11/11 (5 bug-reds now green, 6 guards
stay green: no behavior change outside the mock lane).

Refactor while green: none needed (detector is a separate unit; the
builder change is one arming condition + one helper).

---

## Cycle 2 — targeted suites around the mock lane (regression sweep)

**Date**: 2026-09-14

Command:

```bash
dart test test/plugins/mock/ test/plugins/datasource/ test/plugins/method_append/
```

Result: recorded in `tdd/verification.md` (real run, actual counts) —
the mock lane change must not move the datasource writers, the method
append lane, the certification/certify-gate suites, or the create
capability contracts.
