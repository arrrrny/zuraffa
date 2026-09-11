# Test: the acceptance lane threads declared args, asserts declared
# outcomes, and plans a real make surface (#1512)

- **Slug**: 1512-acceptance-vacuous-composition
- **Suite**: `test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart`
- **Method**: content-level rendering through `BehaviorTestWriter.write()`
  into temp trees (the bug_830/bug_912 convention) + pure planner calls
  (`GenerationPlanner.plan()` over `BehaviorSummary`) — no filesystem
  preconditions beyond the temp fixtures.

## Fixtures

| Fixture | Shape |
| ------- | ----- |
| `acceptanceBehavior()` | an `A1` acceptance row (configurable description/target) |
| `shapeOf(...)` | `UnitContractShape.of(Signature.parse(...))` — scalar (`-> String`), entity (`-> Todo` → `Object?`), void (`-> void`) |
| `acceptanceSummary(...)` | acceptance-kind `BehaviorSummary` rows with scenario prose / explicit targets / CRUD prose / non-acceptance control |
| unit guardrail rows | `U1` scalar-shape + `U2` undeclared unit rows (the byte-for-byte lane pins) |

## Behaviors

| id | assertion |
| -- | --------- |
| A-1512-a1 | a declared scalar contract threads the declared arg literal into the call site: `return subject.subject_a1(r'sample');` — the empty call `subject.subject_a1();` and the `return null;` discard are gone |
| A-1512-a2 | a declared entity return (renderable `Object?` degradation) threads args AND returns the result |
| A-1512-a3 | a declared VOID return keeps the void-safe capture (`use_of_void_result` can never enter the emitted pair) while still threading the declared args |
| A-1512-b1 | a declared scalar outcome asserts `expect(result, isA<String>())` and `contentIsVacuousGreen(content)` is false |
| A-1512-b2 | a declared entity outcome carries the `vacuousGuardMarker` seam (mechanically refused, never silent) |
| A-1512-b3 | an UNDECLARED acceptance fallback guard carries the marker seam too — an empty body can no longer pass silently |
| A-1512-c1 | a plain scenario row plans the spec-052 composition lane: `tdd compose A1 --feature <f>` → `build` (expressible, not unexpressible) |
| A-1512-c2 | a scenario row whose literals name an entity plans the #758 entity pipeline: `entity create -n Todo` → `make Todo` → `tdd wire A1 --entity Todo --feature <f>` → `build` |
| A-1512-c3 | an explicit target wins the entity derivation |
| A-1512-c4 | the honest #758 refusal stays: CRUD prose with no named entity keeps the actionable unexpressible stop (`names no entity`) |
| A-1512-c5 | non-acceptance rows keep the generic misfire (the new branch steals nothing) |
| A-1512-d1 | unit scalar capture keeps the inferred annotation, threaded args, `isA<bool>()`, NO marker (unit lane byte-for-byte) |
| A-1512-d2 | the undeclared unit fallback guard stays UNMARKED (the #1308 two-class dispatch is untouched) |
