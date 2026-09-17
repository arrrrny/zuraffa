# 1691-unit-scaffold-entity-param-import

- **Spec ID**: 1691-unit-scaffold-entity-param-import
- **Created**: 2026-09-18
- **Source**: GitHub issue #1691 (tdd/unit-lane: test scaffold references lifted entity param type in `_argN()` helper without importing it — verify-red dies at compile-error)
- **Type**: code-generation fix (P1 — every unit behavior whose declared param is an on-disk entity cannot reach the designed red phase)
- **Branch**: fix/1691-unit-scaffold-entity-param-import
- **Related**: SPEC 1489 (the lift that exposed it: `UnitContractParam.type` lifted from `Object?` to the declared type for on-disk entities), spec 991 (the `_argN()` placeholder seam), SPEC 1489 SC-2 (the subject writer's entity-import block — the pattern the test writer was missing), #1420 (entity-row gen harness shape), #1538 (void-returning contracts — the same capture site)

## Problem

The unit-lane test scaffold references a lifted entity param type in its
`_argN()` placeholder helper without importing it, so `verify-red` dies at
`compile-error` instead of reaching the designed honest-red / hand-seam
transition. It fires whenever a unit behavior's declared param is an entity
that already exists on disk at gen time.

Repro (`zfa setup login_probe --flutter` → spec with entity param in the
Domain row → `zfa tdd plan 001-login` → `zfa tdd run 001-login`):
`verify-red -> compile-error`:

```
test/tdd/001-login/u1_test.dart:24:7: Error: 'LoginParams' isn't a type.
      LoginParams _arg0() => throw UnimplementedError('provide a representative argument for subject_u1 (declared param 0: LoginParams)');
```

The generated test imports the RETURN entity (`user_session.dart`) but not
the PARAM entity (`login_params.dart`).

### Root cause

SPEC 1489 lifted `UnitContractParam.type` from `Object?` to the declared
type when the entity exists on disk (`unit_contract_shape.dart`,
`UnitContractShape.of`, params loop). The test scaffold then emits the
helper with the lifted type at
`lib/src/plugins/tdd/services/behavior_test_writer.dart:624`, but the test
writer only adds `returnEntityImports` to the test's import set — not
`entityImports`. The design comment at `unit_contract_shape.dart:238-242`
("never the param entities... no unused imports") holds only for the
PRE-1489 degradation (`Object? _arg0()` needs no import). After the lift,
the helper references the type and the import is required — and guaranteed
USED, because `entityImports` only contains entities that exist on disk
(the exact lift condition).

The SUBJECT writer already emits the full `entityImports` list (SPEC 1489
SC-2) — the test writer was not extended the same way.

## Suggested fix

In the unit-lane test scaffold writer
(`behavior_test_writer.dart`, `_testEntityImportLines`), add
`shape.entityImports` to the test's import set (dedup with
`returnEntityImports`). Unused-import risk is nil by construction.

## Hard constraints

- Fix ONLY the test scaffold writer import set; do NOT change
  `UnitContractShape` lift semantics or the SUBJECT writer; one PR per
  spec.
- The fix must:
  1. add `entityImports` to the test's import set with dedup,
  2. not introduce unused imports (entries exist only for on-disk
     entities),
  3. make the login_probe repro compile with honest-red instead of
     compile-error,
  4. keep scalar-param behavior unchanged.

## Goal

`verify-red` on the login_probe repro certifies an honest red
(classification `assertion`, the UnimplementedError guard or arg-placeholder
hand seam) instead of dying at `compile-error`, with no regression on the
scalar-param path (zcalc probe: the scalar contract template stays
byte-identical — no entity import block).

## Success criteria (measurable)

- **SC-1**: In the login_probe repro (declared contract
  `AuthRepo: login(LoginParams) -> UserSession`, both entities on disk at
  gen time), the regenerated `test/tdd/001-login/u1_test.dart` imports the
  PARAM entity AND the return entity (param first — the shape's documented
  `entityImports` order), the `_argN()` helper still renders the lifted
  type, and `zfa tdd verify-red U1` classifies `assertion` with
  `certified=true` (red evidence appended to the cycle log).
- **SC-2**: The latent scalar-return shape
  (`fetch(LoginParams) -> bool`, param entity on disk) also imports the
  param entity — the return-only import set missed it even though the
  helper references the lifted type there too.
- **SC-3**: The scalar-only contract (`add(int a, int b) -> int`) keeps the
  legacy template byte-for-byte: no `_argN()` helper (representative
  literals), no entity import block (`domain/entities/` absent from the
  test).
- **SC-4**: The full unit-scaffold regression suite stays green:
  `test/plugins/tdd/commands/spec_1691_unit_scaffold_entity_param_import_test.dart`
  (new, 3 tests) plus the existing writer/shape suites
  (`behavior_test_writer_test.dart`, `unit_contract_shape_1489_test.dart`,
  `bug_1420_entity_row_gen_test.dart`, `subject_provenance_1565_test.dart`)
  pass unmodified.
- **SC-5**: The zcalc probe path (scalar params) certifies an honest red
  the same way it did before the fix — `verify-red` classification
  `assertion`, `certified=true`.
