# Plan: SPEC 1489 — Entity-Return Renderability

**Feature ID:** 1489-entity-return-renderability
**Spec:** [spec.md](spec.md)

## Technical Context

**Language/version:** Dart ^3.11.0 (SDK 3.13.3 in the working environment)
**Dependencies touched:** none added — `locateEntityFile` already lives in
`lib/src/plugins/tdd/services/entity_lookup.dart`; the shape module already
imports the routing model.

**Primary surfaces (the fix):**

| File | Role |
| ---- | ---- |
| `lib/src/plugins/tdd/services/unit_contract_shape.dart` | `isRenderableDartType` (lines 47-63) — pure predicate over `_renderableScalars`; `UnitContractShape.of` (line 123) — degrades non-scalars to `Object?`; `scalarOutcome` (line 163) — routes the paired test's assertion surface. |
| `lib/src/plugins/tdd/services/subject_writer.dart` | `_renderContractUnitSubject` (lines 187-232) — renders the subject; header claims the degradation lifts "when implementing" but nothing implements it. |
| `lib/src/plugins/tdd/commands/run_driver_core.dart` | Phase-0 (`_runEntityPhaseZero`, lines 2245-2390) guarantees entities exist via `locateEntityFile` BEFORE gen spawns; lane announce block is the seam-cost forecast surface. |
| `lib/src/plugins/tdd/services/entity_lookup.dart` | `locateEntityFile(cwd, name)` — canonical `lib/src/domain/entities/<snake>/<snake>.dart`, recursive fallback. READ ONLY (no fix needed). |

**Consumer call-sites (minimal mechanical threading of the new data):**

| File | Change |
| ---- | ------ |
| `lib/src/plugins/tdd/commands/gen_command.dart` (line 853) | `UnitContractShape.of(declared)` → `UnitContractShape.ofResolved(declared, cwd: cwd)` — the single line that gives the shape the registry. |
| `lib/src/plugins/tdd/services/behavior_test_writer.dart` | Paired test emits the return-entity import when the assertion references the declared type (`scalarOutcome` via the entity path). |

**Surrogate call-site (FR-4):** `lib/src/plugins/tdd/commands/plan_command.dart`
computes N/M with the shared helper and renders the seam-cost line in the
test list + summary output.

## Design

### Data flow (all new facts ride the existing `contractShape`)

```
phase-0 (run driver)            creates/verifies entities on disk
        │
gen spawns                      entity files exist under lib/src/domain/entities/
        │
gen_command.dart:853            UnitContractShape.ofResolved(declared, cwd: cwd)
        │                           ├─ collects candidate entity base names
        │                           ├─ locateEntityFile(cwd, name) per candidate
        │                           ├─ resolves the consumer's package name (pubspec)
        │                           └─ UnitContractShape.of(sig, entityExists:, entityFiles:)
        │
UnitContractShape               returnType = declared type when renderable
                                entityImports / returnEntityImport (baked URIs)
                                entityReturn / scalarOutcome (corrected)
        │
SubjectWriter                   renders declared types + import block
BehaviorTestWriter              isA<Task>() + the return-entity import
```

### Key decisions

1. **The predicate stays sync; the registry is async.** `locateEntityFile`
   is `Future`. `isRenderableDartType` gains an OPTIONAL sync predicate
   (`bool Function(String entityName)? entityExists`); the new
   `UnitContractShape.ofResolved` does the async resolution ONCE, then feeds
   a sync membership check into `of`. Legacy callers (`func_command.dart`,
   direct-`of` tests) never pass it — byte-identical behavior today.
2. **Import URIs are baked into the shape.** The staleness re-render (bug
   #683) compares bytes against a temp mirror render; a URI resolved from
   the render-time context would differ between the real pair and the
   mirror and force infinite regeneration. Resolving the package name and
   entity paths at shape-derivation time keeps every render of one shape
   byte-identical.
3. **`scalarOutcome` gains the entity dimension, honestly.** When the
   declared return is an entity AND the entity exists, `isA<Task>()` is a
   mechanically assertable outcome (it is NOT the bare guard), so
   `scalarOutcome := returnRenderable && (isAssertableScalarType(return) ||
   entityReturn)`. `void`/`dynamic`/`Object`/`Never` stay excluded. Missing
   entities keep `scalarOutcome == false` → the #1308 vacuous-guard seam is
   byte-identical (FR-5).
4. **Test-side import is conditional.** Only the RETURN entity's import is
   emitted into the paired test (the assertion is the only place a test
   references it); param entities keep the `_argN()` placeholder seam (spec
   991) and are NOT imported — no `unused_import` warnings, FR-011 holds.
5. **Seam cost is a forecast of scalarOutcome==false over entity-shaped
   declared returns.** N = unit behaviors whose declared contract returns an
   entity that does NOT exist on disk; M = unit behaviors total. Surfaced by
   `zfa tdd plan` (test list + stdout) and the run driver's announce.

## Risks / Compatibility

- **Backwards compat (FR-5):** every new parameter is optional; `of` with no
  registry produces today's shapes; missing entities degrade exactly as
  before; the #1308 marker path is untouched.
- **Determinism:** package-URI fallback to a lib-relative URI keeps renders
  stable in pubspec-less fixture contexts.
- **State machine:** untouched. The announce line is output-only and gated
  on N > 0.

## Verification Strategy

Fast-tier tests only (cloud agent discipline, `dart_test.yaml`):
`test/plugins/tdd/services/unit_contract_shape_1489_test.dart` (RED first),
plus the existing subject-writer / #1308 / #1259 suites as no-regression
guards. `dart analyze` over the changed files. `dart format` clean.
