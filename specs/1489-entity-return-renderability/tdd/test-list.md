# TDD Test List — SPEC 1489 (entity-return renderability)

**Feature:** 1489-entity-return-renderability
**Tier:** fast (cloud-agent discipline — `dart test` default per `dart_test.yaml`)

## Unit behaviors (fast tier)

| id | test | asserts (SC) | state |
| -- | ---- | ------------ | ----- |
| U-1489-1 | `isRenderableDartType` lifts an existing entity: `Task`, `Task?`, `List<Task>`, `Set<Task>`, `Iterable<Task>`, `Map<String, Task>` | SC-1 | GREEN |
| U-1489-2 | `isRenderableDartType` still degrades a missing entity: `Ghost`, `Ghost?`, `List<Ghost>`, `Map<String, Ghost>` | SC-5 | GREEN |
| U-1489-3 | `isRenderableDartType` without a predicate is byte-for-byte legacy (scalars true, entities false) | SC-5 | GREEN |
| U-1489-4 | `UnitContractShape.of` + registry renders the declared return type and `entityReturn` is true | SC-1 | GREEN |
| U-1489-5 | `UnitContractShape.of` degrades a missing entity return to `Object?`, `scalarOutcome` false, no imports | SC-5 | GREEN |
| U-1489-6 | `UnitContractShape.of` without a registry keeps the legacy shape (`Object?`, no imports, `scalarOutcome` false) | SC-5 | GREEN |
| U-1489-7 | scalar/void/dynamic/Object/Never `scalarOutcome` is unchanged by the registry | SC-3, SC-5 | GREEN |
| U-1489-8 | an existing entity param renders verbatim and carries its import; a scalar return keeps the scalar path | SC-1, SC-2 | GREEN |
| U-1489-9 | nullable and generic entity returns (`Task?`, `List<Task>`, `Map<String, Task>`) carry `returnEntityImports` and assertable outcomes | SC-1, SC-2, SC-3 | GREEN |
| U-1489-10 | `ofResolved` against a real fixture (pubspec + `lib/src/domain/entities/task/task.dart`): declared type + baked `package:` import | SC-1, SC-2 | GREEN |
| U-1489-11 | `ofResolved` with an unresolved entity (and unresolved param): `Object?` everywhere, empty imports | SC-5 | GREEN |
| U-1489-12 | `countEntityReturnSeamsResolved`: counts only the missing entities; scalars and resolved entities are not seams | SC-4 | GREEN |
| U-1489-13 | subject render (existing entity): `Task subject_u1(String title) =>`, the entity import, and NO `replace it with the declared type` instruction | SC-1, SC-2 | GREEN |
| U-1489-14 | subject render (missing entity): `Object? subject_u1(...)`, no entity imports, `does not exist yet` wording | SC-5 | GREEN |
| U-1489-15 | subject render (no registry): the legacy `Object?` subject byte-identical, no imports | SC-5 | GREEN |
| U-1489-16 | paired test (existing entity): `expect(result, isA<Task>());`, no vacuous-guard marker, the return-entity import present | SC-2, SC-3 | GREEN |
| U-1489-17 | paired test (missing entity): the guard path is unchanged — marker present, no `isA<Ghost>` | SC-5 | GREEN |
| U-1489-18 | `countEntityReturnSeams` pure counter: 2 seams out of a mixed return set; registry-less count; zero-seam line suppresses | SC-4 | GREEN |
| U-1489-19 | `entityReturnSeamCostLine`: exact `Seam cost: N of M unit behaviors will hand-step because return is an entity.` wording; null when N = 0 | SC-4 | GREEN |

## Red evidence (recorded before implementation)

```
$ dart test test/plugins/tdd/services/unit_contract_shape_1489_test.dart
  test/.../unit_contract_shape_1489_test.dart:477:27: Error: Member not found:
      'UnitContractShape.entityReturnSeamCostLine'
  test/.../unit_contract_shape_1489_test.dart:172:20: Error: The getter
      'entityReturn' isn't defined for the type 'UnitContractShape'.
  test/.../unit_contract_shape_1489_test.dart:174:20: Error: The getter
      'entityImports' isn't defined for the type 'UnitContractShape'.
00:00 +0 -1: Some tests failed.
```

The suite failed to LOAD — the entire renderability surface (predicate
parameter, shape fields, ofResolved, the counter, the line formatter) did not
exist. After the core shape landed but before the writers did, the three
writer expectations failed RED at the assertion level (subject import block,
paired-test import) and went GREEN with the writer changes — a true
red → green per surface.

## No-regression guards run alongside (fast tier)

| suite | result |
| ----- | ------ |
| `test/plugins/tdd/subject_writer_test.dart` | 5 passed |
| `test/plugins/tdd/bug_1162_subject_shape_test.dart` | 13 passed |
| `test/plugins/tdd/issue_1308_vacuous_guard_remedy_test.dart` | 5 passed |
| `test/plugins/tdd/bug_937_reader_sections_test.dart` | 2 passed |
| `test/plugins/tdd/run_command_test.dart` | passed |
| `test/plugins/tdd/bug_1140_finder_kind_plan_column_test.dart` | passed |
| `test/plugins/tdd/bug_993_plan_entity_export_clash_test.dart` | 17 passed |
| `test/plugins/tdd/two_cycle_run_commands_test.dart` | passed (fast subset) |
| `test/plugins/tdd/plan_skin_contract_test.dart` | 9 passed |
| combined re-run after `dart format` | 60 passed |
