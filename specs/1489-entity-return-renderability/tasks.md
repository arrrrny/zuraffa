# Tasks: SPEC 1489 — Entity-Return Renderability

**MVP-first:** T (tests, red) → I (implementation, green) → V (verification).

## T — TDD red (write the failing tests first)

- [x] T1 (MVP): `test/plugins/tdd/services/unit_contract_shape_1489_test.dart` —
  the RED suite. Covers SC-1..SC-3, SC-5:
  - `isRenderableDartType` with an entity predicate: existing entity → true
    (single, `List<Entity>`, `Entity?`, `Map<String, Entity>`); missing → false;
    no predicate → legacy false.
  - `UnitContractShape.of` with a registry: existing entity return renders the
    declared type (`Task`), missing entity degrades to `Object?`.
  - `scalarOutcome` true for an existing entity return; false for a missing
    entity return; unchanged for scalars/void/dynamic/Object.
  - entityImports/returnEntityImport carry the baked import URIs.
- [x] T2 (MVP): subject-writer render expectations inside the same suite —
  SC-2: the contract unit subject renders the declared return type and the
  entity import; the missing-entity subject stays `Object?` without imports.

## I — Implementation (green)

- [x] T3 (MVP): `unit_contract_shape.dart` — optional `entityExists` predicate
  on `isRenderableDartType` (recursive through generics); `UnitContractShape.of`
  gains `entityExists` + `entityFiles`; new `entityReturn`,
  `entityImports`, `returnEntityImport` fields with const defaults;
  `scalarOutcome` corrected; new `ofResolved(signature, cwd)` doing the async
  registry resolution (`locateEntityFile` + pubspec package name) and baking
  import URIs; doc comments corrected (degradation is conditional —
  unconditional only for non-existent entities).
- [x] T4 (MVP): `subject_writer.dart` — `_renderContractUnitSubject` emits the
  entity import block after `library;` and the corrected degradation wording.
- [x] T5: `gen_command.dart` — thread the registry at the single call-site
  (`ofResolved(declared, cwd: cwd)`).
- [x] T6: `behavior_test_writer.dart` — the paired test emits the
  return-entity import exactly when its assertion references the declared
  type (entity-return `scalarOutcome` path).
- [x] T7: `plan_command.dart` — seam-cost forecast (shared helper) rendered in
  the test list after the unit table and in the summary stdout
  ("N of M unit behaviors will hand-step because return is an entity").
- [x] T8: `run_driver_core.dart` — lane announce carries the same forecast
  when N > 0 (output-only; no state-machine or loop change).

## V — Verification

- [x] T9: `dart analyze` over every changed file — zero issues.
- [x] T10: targeted fast-tier suites (new 1489 suite + subject writer +
  #1308 + #1259-adjacent writers) — green.
- [x] T11: `dart format` — clean; `git diff --stat` reviewed.
- [x] T12: tdd/verification.md written with red→green evidence and
  acceptance-criteria coverage.
