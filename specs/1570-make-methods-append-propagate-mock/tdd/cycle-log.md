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

---

## Cycle 3 — PR #1614 review round: synthesized shapes must compile

**Date**: 2026-09-13 · **Pool task**: `5bd7be01-2162-4fca-9176-ab22929c63e5`

The automated review (`zuraffa-review[bot]`, commit `30eefff9`) found
that the repair only emits correct code for the shapes the tests
covered; three other shapes the interface writer really emits produce
non-compiling output — the same build-gate-red class this feature
exists to remove. Findings: stream bodies typed `Future<void>`
(🔴), synthesized signatures ignoring parameter-less members and
getters (🟠), the drift path re-emitting config members through the
append-or-replace loop (🔵 clobber), a dead `config` parameter +
unreachable null fallback (🔵), a duplicated/weaker implemented-member
scan (🔵), the `pre-#1571` typo (🔵), and verification docs claiming
U1/U2 coverage that was not in the PR (🟡).

RED recorded with a REAL scoped `dart analyze` over the repaired
interface + mock pair (`test/plugins/mock/mock_datasource_builder_1570_compile_test.dart`,
new): 5 issues — `invalid_override` on `dispose(NoParams params)`,
`argument_type_not_assignable` ×3 (`Future<void>` stream bodies),
`conflicting_method_and_field` on the getter-as-method
`isInitialized`. The A5/U1 tests were added alongside; the certify-gate
A6 was re-based on signature-level drift with a state-conditional
analyzer stub (name-level shape drift is repaired before the gate now,
so only signature drift reaches A6's refusal path).

GREEN implementation (same cycle): `ParsedUseCaseInfo` gains
`parameterCount` + `isGetter` (populated by
`MethodExtractor.extractMethodsFromInterface`); the drain synthesizes
mirrored signatures (no `params` when the interface declares none;
getter body for `--init`'s `Stream<bool> get isInitialized`, null
fallback for any other getter); stream bodies delay through
`Future<$returns>` in both the drift synthesis and the custom-usecase
stream branch; the drift repair skips members the mock already
declares (strictly additive — customized bodies survive) and reads the
implemented-member set through `MockStalenessDetector`'s shared
primitive; the dead `config` parameter is dropped; the `#1571` typo is
fixed.

### Cycle 3 GREEN evidence

- `dart test test/plugins/mock/mock_datasource_builder_1570_compile_test.dart`
  → `All tests passed!` (2/2), including the real `dart analyze` over
  the repaired pair (exit 0).
- `dart test test/plugins/mock/mock_datasource_builder_1570_test.dart`
  → `All tests passed!` (15/15; +A5 +U1×2).
- `dart test test/plugins/mock/mock_certify_gate_test.dart` →
  `All tests passed!` (4/4, re-based A6).
