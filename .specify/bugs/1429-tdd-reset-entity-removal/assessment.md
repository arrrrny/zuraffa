# Bug Assessment: TDD reset doesn't revert phase-0 entity_create — no receipted entity-removal verb

- **Slug**: 1429-tdd-reset-entity-removal
- **Created**: 2026-09-15T20:04:47Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/1429
- **Verdict**: valid — reproduced by code-path analysis (receipt lifecycle gap, deterministic)
- **Severity**: high (proof preflight permanently poisoned; requires hand-editing the provenance store to recover)

## Report (verbatim or summarized)

Reporter (zfa 6.2.2, macOS, repo `arrrny/zuraffa_intents`, feature 002-publishable-plugin):
a spec's `### Key Entities` table declared `PlatformException` (a Flutter SDK type — the author meant
documentation of the pigeon error envelope, not a new domain entity). `zfa tdd run` phase-0 honestly
scaffolded it: `entity PlatformException -> created` → `lib/src/domain/entities/platform_exception/`
plus an `entity_create` proof receipt. Realizing the row was over-declared, the author ran
`zfa tdd reset <feature>` — behavior artifacts were reverted but the phase-0 entity creation was NOT.
Hand-deleting the entity files then left the `entity_create` receipt pointing at missing paths, so
`ProofChecker` reports `deleted` findings forever and `zfa tdd verify` for the feature stays blocked by
the receipt preflight. The only escape today is hand-pruning the receipt from `.zfa/receipts/`.
Issue also notes: `zfa entity` has no remove/delete verb that writes a tombstone receipt, and phase-0
creating a domain entity whose name collides with a `package:flutter` type (PlatformException,
BuildContext) deserves at least a warning.

## Symptom

`zfa tdd reset` leaves phase-0 entity scaffolds and their `entity_create` receipts behind; after the
inevitable manual file deletion, `zfa proof check` / `zfa tdd verify` report permanent `deleted` findings
(NOT_ASSESSED verdict) with no CLI path back except hand-editing the provenance store.

## Reproduction

1. Declare `| PlatformException | ... |` under `### Key Entities` in `specs/<feature>/spec.md`.
2. `zfa tdd run <feature>` → phase-0 creates `lib/src/domain/entities/platform_exception/` and an
   `entity create` receipt in `.zfa/receipts/`.
3. `zfa tdd reset <feature>` → behavior artifacts revert; entity dir + receipt remain.
4. Delete `lib/src/domain/entities/platform_exception/` by hand → `zfa proof check` reports
   `deleted` finding for the missing path on every subsequent run; preflight gate stays red.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/reset_command.dart` (`_run()`, lines 118-397): rolls back the feature
  artifact registry (`specs/<f>/tdd/artifacts.json`), run-state, baselines, journal — but never touches
  `.zfa/receipts/` or `lib/src/domain/entities/`.
- `lib/src/plugins/tdd/commands/run_driver_core.dart` (`_runEntityPhaseZero`, lines 3657-3809): phase-0
  spawns the real `zfa entity create`, which writes the receipt via
  `EntityCommand._emitReceipt` → `ReceiptStore.save` (`lib/src/commands/entity_command.dart:505-516`,
  `lib/src/core/project/receipt_store.dart`).
- `lib/src/core/proof/proof_checker.dart` (lines 143-156): unconditionally emits `ProofFinding(kindDeleted)`
  when a receipted path is missing on disk — no tombstone/status awareness anywhere in the checker.
- `lib/src/commands/entity_command.dart` (dispatch switch, lines 114-159): no `remove`/`delete` case.
- `lib/src/utils/flutter_symbols.dart`: Flutter symbol set exists but only for view-generation import
  hiding (#337); it is not consulted by `zfa entity create` and lacks `PlatformException`/`BuildContext`.

## Root Cause Hypothesis

The receipt lifecycle is write-only for entities: phase-0 records `entity_create` receipts in the global
`.zfa/receipts/` store, but neither `tdd reset` (the designed undo verb) nor any `zfa entity` verb
retires them, and `ProofChecker` treats every receipted missing path as a violation regardless of intent.
A legitimately corrected spec therefore poisons the preflight permanently. Secondary: phase-0's honest
scaffolding has no name-collision guard against Flutter SDK types, so documentation-only entity rows
materialize as dead domain code.

## Proposed Remediation

Scope guard (per constraint): only the reset/entity-removal receipt paths change; proof preflight
scoping logic and entity scaffold generation stay untouched.

1. **`zfa tdd reset` rolls back phase-0 entity scaffolds** — after the registry cleanup, read the
   feature's declared entities (`TestListReader.readEntities()`), locate scaffolds
   (`locateEntityFile`), delete the entity scaffold directories, and delete the receipts from
   `.zfa/receipts/` that belong to those entities (`plugin: 'entity'`, `entity: <Name>`). Report
   counts in the reset verdict/summary.
2. **`zfa entity remove <Name>`** — new subcommand: deletes the entity scaffold directory
   (`lib/src/domain/entities/<snake>/`) and writes a tombstone receipt to the provenance store
   (`command: 'entity remove'`, `capability: 'remove'`, file entries with `action: 'delete'`).
   Idempotent recovery: when the scaffold is already gone but receipts exist, still writes the
   tombstone (the exact hand-deleted recovery path from the issue).
3. **Tombstone-aware preflight** — `ProofChecker` skips the `deleted` finding when the latest receipt
   for the missing path carries `action: 'delete'` (a receipted removal = expected absence).
   `ReceiptPreflight` inherits the fix through `ProofChecker.check()`.
4. **Flutter SDK collision warning** — `zfa entity create` warns (`⚠️`) when the entity name collides
   with a known `package:flutter` type name (new curated const set incl. `PlatformException`,
   `BuildContext`), without refusing creation (warning-only per issue). Phase-0 inherits the warning
   because it spawns the real `zfa entity create`.

## Risks & Considerations

- Entity receipts carry no `input['feature']`, so reset scopes receipt deletion by the feature's
  declared entity names; entities shared across features are self-healing (phase-0 re-creates and
  re-receipts on the next run because `entity create` is convergent).
- Tombstone tolerance must key on the *latest* receipt per path so a later re-create receipt still
  governs (latest-wins index already exists in `ProofChecker`).
- Removing an entity whose scaffolds were hand-modified discards those edits — accepted semantics for
  an explicit removal verb and for reset (same contract as behavior-artifact rollback).
- `example/` package requires the Flutter SDK and is out of scope for this fix's verification.

## Open Questions

- None blocking; all four acceptance criteria map to the remediation above.
