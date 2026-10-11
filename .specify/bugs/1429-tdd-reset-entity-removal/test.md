# Bug Test: 1429 — TDD validation record (real runs, no fabricated output)

- **Slug**: 1429-tdd-reset-entity-removal
- **Validated**: 2026-09-15
- **Toolchain**: Dart SDK 3.13.4 (stable), `dart test` (repo `dart_test.yaml`
  presets; concurrency=1)
- **Branch**: `fix/1429-tdd-reset-entity-removal` (base: master `c5ed519f`)

## Test files (all new)

| File | Tier | Behaviors |
| ---- | ---- | --------- |
| `test/plugins/tdd/bug_1429_reset_entity_rollback_test.dart` | in-process `CliRunner(exitOnCompletion: false)` + `TddFixture` + seeded `.zfa/receipts/` | A1, A2, A3 |
| `test/commands/bug_1429_entity_remove_test.dart` | subprocess `runZfaSource` (AOT), `@Tags(['e2e'])` | B1, B2, B3, D1, D2 |
| `test/core/proof/bug_1429_tombstone_preflight_test.dart` | unit (`ProofChecker` + `ReceiptPreflight`) | C1, C2 |

Behavior definitions and traces: `tdd/test-list.md` (this repo root, the
per-bug TDD artifact the previous bug sessions also shipped).

## RED evidence (pre-fix, against base `c5ed519f`)

```
$ dart test test/core/proof/bug_1429_tombstone_preflight_test.dart \
    test/plugins/tdd/bug_1429_reset_entity_rollback_test.dart
00:02 +2 -3: Some tests failed.
Failing tests:
  .../bug_1429_tombstone_preflight_test.dart: C1 (Expected: true  Actual: <false>
      "artifact reported by entity remove is missing; reproduce with:
       zfa entity remove -n Product")
  .../bug_1429_reset_entity_rollback_test.dart: A1 (scaffold survived reset;
      no reverted_entities/pruned_receipts in the verdict)
  .../bug_1429_reset_entity_rollback_test.dart: A2 (Expected: true  Actual: <false>
      "artifact reported by entity create is missing; ...")
```

```
$ dart test test/commands/bug_1429_entity_remove_test.dart
00:00 +1 -4: Some tests failed.
Failing tests:
  .../bug_1429_entity_remove_test.dart: B1, B2, B3
      (Unknown subcommand: remove — exit code 2), D1 (no collision warning)
```

The failing tests fail for exactly the reasons the issue describes: reset
leaves scaffolds + receipts behind; no `entity remove` verb exists; the
preflight has no tombstone notion; create emits no SDK-collision warning.
A3, C2 and D2 are contract guards that pass pre-fix (they pin behavior that
must survive the fix: legacy verdict shape, honest latest-wins drift, the
warning's negative control).

## GREEN evidence (post-fix, this branch)

```
$ dart analyze lib/src/commands/entity_command.dart \
    lib/src/plugins/tdd/commands/reset_command.dart \
    lib/src/plugins/tdd/services/entity_lookup.dart \
    lib/src/core/proof/proof_checker.dart lib/src/utils/flutter_symbols.dart \
    test/plugins/tdd/bug_1429_reset_entity_rollback_test.dart \
    test/commands/bug_1429_entity_remove_test.dart \
    test/core/proof/bug_1429_tombstone_preflight_test.dart
Analyzing entity_command.dart, reset_command.dart, entity_lookup.dart,
proof_checker.dart, flutter_symbols.dart, ...bug_1429_*...
No issues found!

$ dart test test/core/proof/bug_1429_tombstone_preflight_test.dart \
    test/plugins/tdd/bug_1429_reset_entity_rollback_test.dart
00:02 +5: All tests passed!

$ dart test test/commands/bug_1429_entity_remove_test.dart
00:40 +5: All tests passed!
```

## Regression evidence (post-fix, all green)

```
$ dart test test/plugins/tdd/services/receipt_preflight_test.dart \
    test/commands/bug_1378_proof_prune_test.dart test/commands/proof_command_test.dart
00:01 +24: All tests passed!

$ dart test --preset=all test/plugins/tdd/bug_1264_reset_done_state_phantom_test.dart \
    test/plugins/tdd/bug_1331_reset_half_state_test.dart \
    test/plugins/tdd/commands/bug_1380_reset_namespace_guard_test.dart \
    test/plugins/tdd/bug_1495_registry_owns_missing_file_test.dart
00:16 +25 ~1: All tests passed!

$ dart test test/commands/entity_receipt_test.dart test/commands/entity_help_test.dart \
    test/commands/entity_convergent_test.dart test/core/proof/proof_check_valid_test.dart
00:35 +7 -1: ...   (the -1 is a nonexistent file path passed by mistake, not a test)

$ dart test test/commands/entity_create_primitive_types_test.dart \
    test/commands/entity_builder_preflight_test.dart \
    test/commands/entity_cli_exit_code_test.dart test/commands/entity_format_scope_1506_test.dart
00:02 +15: All tests passed!

$ dart test test/utils/
00:04 +138: All tests passed!
```

## Known pre-existing failures (NOT introduced by this fix)

`test/plugins/tdd/bug_840_recovery_commands_test.dart` (tagged `slow`,
excluded from the default tier) is red on master in this environment
BEFORE any change: its `gen --adopt` expectations predate the namespaced
layout, and its `verdict()` helper parses the reset envelope as flattened
top-level keys while the current `VerdictEnvelope.toJsonLine()` nests them
under `details`. Both drift classes are unrelated to #1429; the reset
portions of that file that DO run against the current contract (owned-file
deletion, foreign-kept, registry/run-state reset) exercise code paths this
fix only extends additively (new prints only when entities are declared;
new verdict keys only when present).

## Acceptance criteria mapping

| # | Criterion | Evidence |
| - | --------- | -------- |
| 1 | `zfa tdd reset` rolls back phase-0 entity scaffolds (files + receipts) | A1, A2 (green) |
| 2 | `zfa entity remove <name>` produces a tombstone receipt | B1, B2, B3 (green) |
| 3 | Proof preflight gracefully handles entity deletion — no permanent `deleted` findings | C1, C2 (green); A2 end-to-end |
| 4 | Entity names conflicting with Flutter SDK types emit a warning | D1, D2 (green) |
