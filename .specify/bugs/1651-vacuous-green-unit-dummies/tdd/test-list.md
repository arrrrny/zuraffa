# Test List: 1651-vacuous-green-unit-dummies (#1651)

**Feature**: `.specify/bugs/1651-vacuous-green-unit-dummies` (bug TDD mode)
**Source**: `spec.md` — plan derived via the **LLM-guided fallback path**
(the skills' engine detection contract: `ZFA_MISSING`, no `.zfa.json` in
this repo — the zuraffa repo cannot drive `zfa tdd` on its own development;
matches the `dart-core-lane-timeout-overflow` (#1632) and
`tdd-doctor-feature-positional` (#1585) precedents on this repo).
**Suite**: `test/plugins/tdd/bug_1651_type_only_vacuous_green_test.dart` —
the new pins ride one file, mirroring the `bug_1259_vacuous_green_test.dart`
naming and structure; the four superseded legacy pins are updated in place.

## Unit behaviors

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U1 | `contentIsVacuousGreen` classifies scalar-type-only assertion sets as vacuous — bare `expect(result, isA<int>())`, the guard + type-only pair, and the legacy marker-less generated shape | FR-002 | unit | DONE | test/plugins/tdd/bug_1651_type_only_vacuous_green_test.dart |
| U2 | `contentIsVacuousGreen` keeps value-discriminating assertion sets real — `equals(...)`, `throwsA(...)`, `isNot(isA<...>())`, and entity-type `isA<T>()` each keep the verdict non-vacuous | FR-002 | unit | DONE | test/plugins/tdd/bug_1651_type_only_vacuous_green_test.dart |
| U3 | `BehaviorTestWriter` emits the typed outcome assertion WITH the `zfa:tdd: vacuous-guard` marker + the #1651 remedy comment for a scalar-declared contract (the entity/void marker discipline, extended) | FR-001 | unit | DONE | test/plugins/tdd/bug_1651_type_only_vacuous_green_test.dart |
| U4 | `zfa tdd make` refuses the issue's exact repro — gen (typed assertion, marker) → func fills `return 0;` → test passes → make exits 1 with `outcome=vacuous-green` | FR-001, FR-003 | unit | DONE | test/plugins/tdd/commands/bug_1651_make_dummy_green_refusal_test.dart |

## Acceptance behaviors

| id | behavior | criterion | state |
| -- | -------- | --------- | ----- |
| A1 | pre-fix tree: the new suite FAILS (detector counts the type-only shape real; the writer emits marker-less; make certifies the dummy green) — evidence in `red-evidence.md` | AC-1 | DONE |
| A2 | post-fix tree: the four superseded legacy pins (bug_1259 U5, 1310 U5 + U6, 1538 B1) pass under the new contract and the vacuous-family suites (1259, 1483 ×2, 1308 ×2, 1488, 1626 ×2, 1512, 1320, 1323, 1538) stay green | AC-2 | DONE |

## Contract behaviors

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| contract:VacuousGuardGate | `contentIsVacuousGreen(String) -> bool`: TRUE for the vacuous scalar-type-only shapes, FALSE for value-discriminating sets (the #1007 hand seam — the signature contract is pinned by U1/U2, implemented in `vacuous_guard.dart`) | VacuousGuardGate | contract | DONE | test/plugins/tdd/bug_1651_type_only_vacuous_green_test.dart (U1/U2) |
