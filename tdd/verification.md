# tdd.verify — Bug #1429 tdd reset doesn't revert phase-0 entity_create — no receipted entity-removal verb, permanent proof-preflight `deleted` finding

- **Verified**: 2026-09-15, this session, on
  `fix/1429-tdd-reset-entity-removal` (working tree, pre-push)
- **Toolchain**: Dart 3.13.4 (stable) on linux_x64 (the repo pins
  `sdk: ^3.11.0`); `dart test` with the repo's `dart_test.yaml` presets
  (fast tier by default, `--preset=all` for slow-tagged regression files)
- **Scope**: `lib/src/plugins/tdd/commands/reset_command.dart` (phase-0
  entity rollback + receipt pruning), `lib/src/plugins/tdd/services/
  entity_lookup.dart` (`locateEntityScaffold`), `lib/src/commands/
  entity_command.dart` (`zfa entity remove` + tombstone + SDK-collision
  warning), `lib/src/core/proof/proof_checker.dart` (tombstone guard),
  `lib/src/utils/flutter_symbols.dart` (`flutterSdkTypeNames`), plus the
  three new test files and the per-bug artifacts
  (`.specify/bugs/1429-tdd-reset-entity-removal/`, `tdd/test-list.md`).

## Verdict: PASS

## 1. TDD discipline (red → green → verify)

The loop was driven with the bug directory as the TDD feature. Ten
behaviors were pinned in `tdd/test-list.md` BEFORE the fix, mapped 1:1 to
the issue's four acceptance criteria, and every test in the red set was
observed failing against base `c5ed519f` for exactly the reason the issue
describes — never for a setup error.

```
RED  (pre-fix):  dart test test/core/proof/bug_1429_tombstone_preflight_test.dart
                 test/plugins/tdd/bug_1429_reset_entity_rollback_test.dart
                 → 00:02 +2 -3: Some tests failed.
                 dart test test/commands/bug_1429_entity_remove_test.dart
                 → 00:00 +1 -4: Some tests failed.
                 (A1: scaffold survived reset; A2: preflight still poisoned;
                  C1: "artifact reported by entity remove is missing";
                  B1/B2/B3: "Unknown subcommand: remove"; D1: no warning)

GREEN (post-fix): dart test test/core/proof/bug_1429_tombstone_preflight_test.dart
                  test/plugins/tdd/bug_1429_reset_entity_rollback_test.dart
                  → 00:02 +5: All tests passed!
                  dart test test/commands/bug_1429_entity_remove_test.dart
                  → 00:40 +5: All tests passed!
```

The guards that passed pre-fix (A3 legacy verdict shape, C2 honest
latest-wins drift, D2 warning negative control) still pass post-fix — the
fix added no behavior regression and no vacuous green.

## 2. Static analysis

```
dart analyze lib/src/commands/entity_command.dart \
             lib/src/plugins/tdd/commands/reset_command.dart \
             lib/src/plugins/tdd/services/entity_lookup.dart \
             lib/src/core/proof/proof_checker.dart \
             lib/src/utils/flutter_symbols.dart \
             test/plugins/tdd/bug_1429_reset_entity_rollback_test.dart \
             test/commands/bug_1429_entity_remove_test.dart \
             test/core/proof/bug_1429_tombstone_preflight_test.dart
→ No issues found!
```

`dart format` applied to all changed files.

## 3. Acceptance criteria audit

| # | Criterion | Result | Proof |
| - | --------- | ------ | ----- |
| 1 | `zfa tdd reset <feature>` rolls back phase-0 entity scaffolds — deletes the scaffold files AND retires the `entity_create` receipts | PASS | A1 (scaffold dir deleted, receipts pruned, foreign entity + receipt untouched, `reverted_entities`/`pruned_receipts` in the `--json` verdict) and A2 (the issue's hand-deleted intermediate state: reset prunes the stale receipt and a subsequent `ProofChecker.check()` is green) |
| 2 | `zfa entity remove <name>` (or equivalent) produces a tombstone receipt | PASS | B1 (scaffold dir deleted; receipt `command: 'entity remove'`, `capability: 'remove'`, file entry `action: 'delete'`, stable name `entity-remove-<snake>.json`); B2 (hand-deleted recovery — the issue's documented workaround is now a first-class verb); B3 (refuses an unknown entity with the fix line) |
| 3 | Proof preflight gracefully handles entity deletion — no permanent `deleted` findings | PASS | C1 (poisoned baseline reproduced first, then green via `ProofChecker` AND `ReceiptPreflight` after the tombstone); C2 (honesty guard: recreated bytes after a tombstone still flag `modified`) |
| 4 | Entity names conflicting with Flutter SDK types emit a warning | PASS | D1 (`zfa entity create -n PlatformException` prints `⚠️` naming package:flutter and still creates; phase-0 inherits the warning because it spawns the real verb); D2 (negative control: `Product` warns nothing) |

## 4. Scope-constraint audit

- Proof preflight scoping logic UNCHANGED: `ReceiptPreflight.check` and
  `verify_command._proofPreflightDrift` are untouched; the checker change
  is one guard keyed on the existing receipt `action` field, not new
  scoping.
- Entity scaffold generation UNCHANGED: `EntityCreator`, the phase-0 spawn
  path, and the convergent no-op are untouched; reset/remove only DELETE
  what phase-0 already wrote (via the same lookup helpers phase-0 uses).
- One bug, one PR: every changed file traces to one of the four criteria.

## 5. Regression audit (all green, real runs)

```
dart test test/plugins/tdd/services/receipt_preflight_test.dart
          test/commands/bug_1378_proof_prune_test.dart
          test/commands/proof_command_test.dart        → +24: All tests passed!
dart test --preset=all test/plugins/tdd/bug_1264_reset_done_state_phantom_test.dart
          test/plugins/tdd/bug_1331_reset_half_state_test.dart
          test/plugins/tdd/commands/bug_1380_reset_namespace_guard_test.dart
          test/plugins/tdd/bug_1495_registry_owns_missing_file_test.dart
                                                       → +25 ~1: All tests passed!
dart test test/commands/entity_receipt_test.dart test/commands/entity_help_test.dart
          test/commands/entity_convergent_test.dart
          test/core/proof/proof_check_valid_test.dart  → +7: passed
dart test test/commands/entity_create_primitive_types_test.dart
          test/commands/entity_builder_preflight_test.dart
          test/commands/entity_cli_exit_code_test.dart
          test/commands/entity_format_scope_1506_test.dart
                                                       → +15: All tests passed!
dart test test/utils/                                 → +138: All tests passed!
```

Pre-existing, unrelated red (master, unchanged by this fix):
`bug_840_recovery_commands_test.dart` (slow tier) — its expectations predate
the namespaced artifact layout and the current `details`-nested envelope
shape. Verified red on the untouched base commit before any edit.

## 6. Remaining risks / notes for reviewers

- Reset scopes receipt pruning by the feature's DECLARED entity names
  (entity receipts carry no `input['feature']`); a shared entity is
  self-healing because phase-0 re-creates and re-receipts it on the next
  run (`entity create` is convergent).
- The tombstone uses the stable receipt name `entity-remove-<snake>.json`
  (refreshed in place, the `mock-<entity>.json` precedent), so repeated
  removes do not accumulate documents.
- A file recreated after a tombstone carries the empty-content digest
  (`_handleRemove` deletes the scaffold before `digestFor` runs), so any
  non-empty recreation flags `modified` — verified by C2 (different
  bytes → modified; never a silent pass).
