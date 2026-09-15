---
feature: 1429-tdd-reset-entity-removal
loop: inside-out
profile: .specify/memory/tdd-profile.md
spec_criteria: 4
planned_at: c5ed519f
updated_at: c5ed519f
suite_baseline: green
---

# Test List — Bug 1429 (tdd reset entity rollback / entity remove / tombstone preflight / SDK warning)

Source of truth: https://github.com/arrrrny/zuraffa/issues/1429 and
`.specify/bugs/1429-tdd-reset-entity-removal/assessment.md`.

The behaviors below are pinned to the bug workflow (the bug directory is the
TDD feature). Every behavior maps 1:1 to an acceptance criterion from the
issue. All tests are new files — they must be RED on `c5ed519f` before the fix
lands, and GREEN after.

## Behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | `zfa tdd reset <feature>` reverts the phase-0 entity scaffolds declared by the feature's test list (deletes the canonical per-entity directory) and prunes the entity receipts belonging to those declared names; entities NOT declared by the feature (foreign scaffolds + their receipts) are never touched; the JSON verdict reports `reverted_entities` | AC-1 | RED |
| A2 | Reset heals the poisoned intermediate state from the issue: declared entity whose scaffold was hand-deleted but whose `entity_create` receipt remains → reset prunes the receipt and a subsequent `ProofChecker.check()` is green (no permanent `deleted` finding) | AC-1, AC-3 | RED |
| A3 | Reset without declared entities keeps its verdict shape and prunes nothing (backward compatibility for legacy features without a Key Entities section) | AC-1 | RED |
| B1 | `zfa entity remove -n <Name>` deletes the entity scaffold directory and writes a tombstone receipt: `command: 'entity remove'`, `capability: 'remove'`, `entity: <Name>`, file entry `action: 'delete'` for the scaffold path | AC-2 | RED |
| B2 | `zfa entity remove` is the documented recovery path from the issue: when the scaffold is already hand-deleted but entity receipts remain, remove still succeeds and writes the tombstone (no hand-editing the provenance store) | AC-2, AC-3 | RED |
| B3 | `zfa entity remove` refuses an entity that never existed (no scaffold, no receipts) with a non-zero exit and the machine-actionable fix line | AC-2 | RED |
| C1 | `ProofChecker` (and therefore `ReceiptPreflight` / `zfa proof check` / `zfa tdd verify`) treats a missing artifact whose LATEST receipt entry carries `action: 'delete'` as provenance, not drift: no `deleted` finding, report ok; the same missing artifact WITHOUT a tombstone still reports `deleted` (baseline poisoning reproduced first) | AC-3 | RED |
| C2 | Tombstone tolerance stays honest under latest-wins: recreating the file after a tombstone with different bytes still flags drift (`modified`), never a silent pass | AC-3 | RED |
| D1 | `zfa entity create -n PlatformException` (a Flutter SDK type name) emits a `⚠️` collision warning naming `package:flutter` and still creates the entity (warning, never a refusal — phase-0 inherits the warning because it spawns the real `zfa entity create`) | AC-4 | RED |
| D2 | `zfa entity create -n Product` emits no SDK-collision warning (negative control) | AC-4 | RED |

## Mappings

- A1–A3 → `test/plugins/tdd/bug_1429_reset_entity_rollback_test.dart` (in-process
  `CliRunner(exitOnCompletion: false)` + `TddFixture`, `--json` verdict parsing)
- B1–B3, D1–D2 → `test/commands/bug_1429_entity_remove_test.dart`
  (`runZfaSource` subprocess tier — `entity` calls `exit()` on error paths)
- C1–C2 → `test/core/proof/bug_1429_tombstone_preflight_test.dart`
  (unit tier: `ProofChecker` + `ReceiptPreflight` against a seeded
  `.zfa/receipts/` store)

## Cycle log (summary — full evidence in `.specify/bugs/1429-tdd-reset-entity-removal/test.md`)

- Cycle 1 (A1–A3, B1–B3, C1–C2, D1–D2): RED recorded against `c5ed519f`.
- Cycle 2: minimal fix — reset entity rollback (reset_command.dart +
  entity_lookup.dart `locateEntityScaffold`), `zfa entity remove` +
  tombstone (entity_command.dart), tombstone-aware `ProofChecker`
  (proof_checker.dart), Flutter SDK collision warning (flutter_symbols.dart +
  entity_command.dart). GREEN recorded.
