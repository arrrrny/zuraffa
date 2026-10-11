# Test: the acceptance lane's fallback naming, void-safe capture, and real
# make surface (#1512)

- **Slug**: 1512-acceptance-vacuous-composition
- **Suite**: `test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart`
- **Method**: content-level rendering through `BehaviorTestWriter.write()`
  into temp trees (the bug_830/bug_912 convention) + pure planner calls
  (`GenerationPlanner.plan()` over `BehaviorSummary`) + one slow
  `dart test` run over the emitted test+subject pair (the compile proof —
  the round-2 review asked for the pair, not only its text).

## Fixtures

| Fixture | Shape |
| ------- | ----- |
| `acceptanceBehavior()` | an `A1` acceptance row (configurable description/target) |
| `shapeOf(...)` | `UnitContractShape.of(Signature.parse(...))` — scalar (`-> String`), entity (`-> Todo` → `Object?`) |
| `acceptanceSummary(...)` | acceptance-kind `BehaviorSummary` rows with scenario prose / explicit entity prose / explicit targets / CRUD prose / non-acceptance control |
| unit guardrail rows | `U1` scalar-shape + `U2` undeclared unit rows (the byte-for-byte lane pins) |

## Behaviors

| id | assertion |
| -- | --------- |
| A-1512-a1 | an undeclared acceptance row emits the parameterless void-safe capture (`subject.subject_a1();` + `final Object? result` + `return null;`) |
| A-1512-a2 | a directly-injected scalar shape is INERT for acceptance — no threaded args, no returned result, no `isA<T>()` (the composition `gen` never builds) |
| A-1512-a3 | a directly-injected entity-return shape is inert too |
| A-1512-a4 | the paired subject `SubjectWriter` emits is the parameterless `void subject_a1()` runner the test's call is arity-compatible with |
| A-1512-b1 | the undeclared acceptance fallback carries `acceptanceFallbackGuardToken` — and NOT `vacuousGuardMarker`; `contentIsVacuousGreen` is still true |
| A-1512-b2 | the acceptance fallback does not reuse the unit-lane `vacuousGuardComment` block |
| A-1512-c1 | a plain scenario row plans the spec-052 composition lane: `tdd compose A1 --feature <f>` → `build` (expressible, not unexpressible) |
| A-1512-c2 | an incidental capitalised word does NOT fabricate an entity — `the User signs in.` composes |
| A-1512-c3 | a row naming an entity only by a capitalised word composes (no entity pipeline from prose alone) |
| A-1512-c4 | an explicit `entity <Name>` prose signal plans the #758 entity pipeline: `entity create -n Todo` → `make Todo` → `tdd wire A1 --entity Todo --feature <f>` → `build` |
| A-1512-c5 | an explicit `create <Name>` prose signal plans the entity pipeline too |
| A-1512-c6 | an explicit target wins the entity derivation |
| A-1512-c7 | the honest #758 refusal stays: CRUD prose with no named entity keeps the actionable unexpressible stop (`names no entity`) |
| A-1512-c8 | non-acceptance rows keep the generic misfire (the new branch steals nothing) |
| A-1512-d1 | unit scalar capture keeps the inferred annotation, threaded args, `isA<bool>()`, NO marker, NO acceptance token (unit lane byte-for-byte) |
| A-1512-d2 | the undeclared unit fallback guard stays UNMARKED and carries no acceptance token |
| A-1512-e1 (slow) | the emitted acceptance test+subject pair compiles and fails through an assertion — never a compile-time error (the round-2 compile proof) |
