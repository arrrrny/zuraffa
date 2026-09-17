# Plan: 1691-unit-scaffold-entity-param-import

- **Spec ID**: 1691-unit-scaffold-entity-param-import
- **Created**: 2026-09-18

## Technical Context

- **The import sets** (SPEC 1489, `unit_contract_shape.dart`):
  `UnitContractShape.entityImports` is the deduplicated, insertion-ordered
  set of import URIs for every EXISTING entity the declared signature
  references — params first (declaration order), then the return —
  resolved by `ofResolved` through `locateEntityFile` (the same registry
  fact the run driver's phase-0 consults), with lint-clean `package:` URIs
  when the consumer's pubspec name resolves.
  `UnitContractShape.returnEntityImports` is the SUBSET those URIs that
  the declared RETURN references. Every entry exists only for an entity
  on disk at gen time — the exact condition under which SPEC 1489 lifts
  `UnitContractParam.type` from `Object?` to the declared type.
- **The subject side (already correct)**: `subject_writer.dart:244-246`
  emits `shape.entityImports` as the stub's import block (SPEC 1489 SC-2)
  — the subject compiles against the declared types out of the box.
- **The test side (the bug)**: `behavior_test_writer.dart`'s
  `_testEntityImportLines()` gated the test's entity-import block behind
  the RETURN surface only: `!shape.scalarOutcome → ''`,
  `isAssertableScalarType(shape.declaredReturn) → ''`, then emitted
  `shape.returnEntityImports`. Meanwhile `_captureInvocation` (line 624)
  renders the `_argN()` placeholder helper as
  `"${param.type} _arg$i() => throw UnimplementedError(...)"` — with the
  LIFTED type after SPEC 1489. A declared param entity that exists on disk
  therefore produces a test referencing an unimported type:
  `verify-red -> compile-error`.
- **Why every import is guaranteed used (no unused-import risk, by
  construction)**:
  - A lifted entity PARAM always takes the `_argN()` helper seam: the
    representative-literal table (`_scalarLiteral`) covers only
    String/int/num/bool/double/Object, and the scenario-argument resolver
    (`ScenarioValue.fitsType`) only fits scalars — an entity-typed param
    can never claim a literal, so the helper is always emitted and always
    names the lifted type (`List<Task>` and `Map<String, Task>` params
    recurse into the same entity names).
  - A lifted entity RETURN always feeds the typed assertion:
    `entityReturn ⇒ scalarOutcome`, `expectedForType` never fits an entity
    type, so `_declaredAssertion` emits
    `expect(result, isA<DeclaredReturn>())`.
  - Legacy shapes (no registry, no `ofResolved`) and scalar-only shapes
    have `entityImports` empty — the import block is empty and the
    template stays byte-identical.
- **The guard removal is semantic, not cosmetic**: the two return-centric
  early-returns excluded exactly the shapes the issue fires on. Dropping
  them (keeping `shape == null` for the acceptance lane, which never
  resolves a shape — issue #1512) makes the block describe what the test
  actually references: every entity type in the emitted source.

## Remediation

`lib/src/plugins/tdd/services/behavior_test_writer.dart` — ONE writer, ONE
method:

- `_renderTest`: the import-rationale comment updated (param entities are
  imported since the lift — the spec 991 seam renders the lifted type).
- `_testEntityImportLines()`: emit the full `shape.entityImports` set
  (dedup is inherent — the shape derivation builds it from a
  `LinkedHashSet`; `returnEntityImports` ⊆ `entityImports`). Guards
  reduced to `shape == null` (acceptance/legacy callers) and the
  empty-set case.

`UnitContractShape`, the SUBJECT writer, and every other writer stay
untouched (one PR per spec).

## Verification plan (the two-probe matrix)

- **login_probe repro (entity param + entity return, Flutter probe)**:
  `zfa setup login_probe --flutter` → `specs/001-login/spec.md` with
  `AuthRepo: login(LoginParams) -> UserSession` in the Domain row →
  `zfa tdd plan 001-login` → phase-0 creates both entities → gen U1 →
  verify-red. PRISTINE TREE: `classification: compile-error`,
  `certified=false` (the bug, red evidence). FIXED TREE: regenerated test
  imports `login_params` + `user_session` (param first), verify-red
  classifies `assertion`, `certified=true` (SC-1).
- **zcalc_probe (scalar contract, Dart probe)**: declared
  `Calculator: add(int a, int b) -> int` → gen U1 → the template keeps the
  legacy shape (representative literals `subject_u1(0, 0)`, no
  `_argN()`, no `domain/entities/` import) → verify-red classifies
  `assertion`, `certified=true` (SC-3, SC-5).
- **Fast-tier regression tests** (the bug_1420 harness shape — real
  GenCommand via CliRunner, no pub get, no build):
  `test/plugins/tdd/commands/spec_1691_unit_scaffold_entity_param_import_test.dart`
  pins SC-1 (both imports, param-first order), SC-2 (entity param + scalar
  return), SC-3 (scalar-only byte-stability).
- **Suite**: the existing writer/shape suites
  (`behavior_test_writer_test.dart`, `unit_contract_shape_1489_test.dart`,
  `bug_1420_entity_row_gen_test.dart`,
  `subject_provenance_1565_test.dart`) run unmodified, then the CI fast
  lane (`dart test test --exclude-tags "flutter || e2e"`) as the budget
  allows in the verification sandbox.

## Verification run context (provenance for tdd/verification.md)

The `tdd/verification.md` committed with this spec is produced by
`zfa tdd verify --feature 001-login` inside the login_probe verification
project (the repro of record), with the FIXED zuraffa source tree — the
feature whose red/green/mutation evidence the cycle-log records. The
sandbox disk budget (~9.9GB root fs, dart-test kernel cache ≈ 20-45MB per
test file) is documented in the verification notes: the repo suite ran in
file-batches with fresh kernel caches per batch to stay inside the budget
(the CI lane itself is unchanged and runs unsharded on CI-sized agents).
