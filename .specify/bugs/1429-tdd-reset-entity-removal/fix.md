# Bug Fix: 1429 — tdd reset entity rollback, receipted entity removal, tombstone-aware preflight, SDK collision warning

- **Slug**: 1429-tdd-reset-entity-removal
- **Fixed**: 2026-09-15 (branch `fix/1429-tdd-reset-entity-removal`)
- **Issue**: https://github.com/arrrrny/zuraffa/issues/1429
- **Assessment**: [assessment.md](assessment.md)

## Scope guard (per constraint)

Only the reset/entity-removal receipt paths were touched. The proof preflight
scoping logic (`ReceiptPreflight.check`, `verify_command._proofPreflightDrift`)
and the entity scaffold generation (`EntityCreator`, run_driver_core phase-0)
are unchanged — the checker change below only suppresses a finding whose
meaning the existing receipt model already encoded (`action: 'delete'`).

## Root cause (one paragraph)

The receipt lifecycle for entities was write-only: phase-0 recorded
`entity create` receipts in the global `.zfa/receipts/` store, but neither
`zfa tdd reset` (the designed undo verb) nor any `zfa entity` verb retired
them, and `ProofChecker` treated every receipted missing path as a violation.
A legitimately corrected spec therefore poisoned the preflight permanently,
and the only escape was hand-editing the provenance store.

## Changes (5 files, +~530/−42 lines incl. tests)

1. **`lib/src/plugins/tdd/commands/reset_command.dart`** — after the registry
   load, reset reads the feature's declared entities via
   `TestListReader(featureDir).readEntities()` (the SAME source the run
   driver's phase-0 reads) and plans the rollback with
   `locateEntityScaffold`. Announced before acting (the diff-summary
   contract): `will revert N declared phase-0 entity scaffold(s)` +
   `will prune N entity receipt(s)`. Acting: canonical per-entity
   directories (`lib/src/domain/entities/<snake>/`) are deleted whole;
   receipt files with `plugin: 'entity'` and `entity: <declared name>` are
   pruned from `.zfa/receipts/`. Failure semantics follow the existing
   outcome-validation contract: a scaffold or receipt that survives is
   named and the reset refuses (exit 1). The verdict gains
   `reverted_entities` and `pruned_receipts` details, and the text summary
   line gains `entities_reverted=` / `receipts_pruned=`. Scoping honesty:
   entity receipts carry no `input['feature']`, so the declared names are
   the only honest feature scoping available; a shared entity is
   self-healing (the next run's phase-0 re-creates and re-receipts it —
   `entity create` is convergent).
2. **`lib/src/plugins/tdd/services/entity_lookup.dart`** — new
   `locateEntityScaffold(cwd, name)`: locates the scaffold (same
   `locateEntityFile` + `toSnakeCase` conversion phase-0 uses) and
   classifies the deletable shape — the canonical per-entity directory
   when the file follows `<entities>/<snake>/<snake>.dart`, the file only
   when a recursive fallback found it in a foreign layout (never a
   rollback target). Shared by reset and `entity remove` so both verbs and
   phase-0 agree on one path contract.
3. **`lib/src/commands/entity_command.dart`** — new `remove` subcommand
   (alias `delete`): deletes the scaffold and writes a TOMBSTONE receipt
   (`command: 'entity remove'`, `capability: 'remove'`, file entries
   `action: 'delete'`) via `ReceiptStore.saveNamed` under the stable name
   `entity-remove-<snake>.json` (refreshed in place on re-runs, the
   `mock-<entity>.json` precedent). The tombstone covers the union of
   paths the entity's prior receipts shipped plus the located scaffold.
   Idempotent recovery (the exact path the issue documents): when the
   scaffold is already gone but entity receipts remain, the tombstone is
   still written — a corrected spec never again requires hand-editing the
   store. Refuses (exit failure + fix line) an entity with neither
   scaffold nor receipts. Help text documents the verb. Additionally,
   `entity create` now warns (`⚠️`) when the name collides with a Flutter
   SDK type name — a warning, never a refusal.
4. **`lib/src/core/proof/proof_checker.dart`** — one guard in the
   digest-verification scan: when the LATEST receipt entry covering a
   missing path carries `action: 'delete'`, the absence is provenance, not
   drift — no `deleted` finding. Latest-wins semantics keep it honest: a
   recreated file after a tombstone lands in the digest check (modified on
   mismatch). `ReceiptPreflight`, `zfa proof check` and `zfa tdd verify`
   inherit the tolerance through `ProofChecker.check()` unchanged.
5. **`lib/src/utils/flutter_symbols.dart`** — new curated
   `flutterSdkTypeNames` const set (≈50 `package:flutter` type names incl.
   `PlatformException`, `BuildContext`) + `collidesWithFlutterSdkType`.
   Deliberately distinct from `flutterMaterialCollidingSymbols` (the view
   generator's import-hiding contract): this set is the create-time lint
   and SHOULD contain the symbols generated views use. phase-0 inherits
   the warning because it spawns the real `zfa entity create`.

## Verification

- RED → GREEN cycle with 10 pinned behaviors (see [test.md](test.md) and
  `tdd/test-list.md`); real command output preserved in both.
- `dart analyze` on all changed files: `No issues found!`
- Regression suites re-run green: receipt preflight, proof prune (#1378),
  proof check CLI, reset suites (#1264, #1331, #1380, #1495), entity
  receipt/help/convergent/primitive-types/builder-preflight/cli-exit-code/
  format-scope, and the full `test/utils/` folder.
- `dart format` applied to all changed files.
