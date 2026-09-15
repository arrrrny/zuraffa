# Quickstart: 1652-refactor-digest-gate

Validation guide — prove the phase-1 refactor inherits make's certified
post-state on an untouched tree, and that every mismatch re-runs the
full pipeline. All commands run from the repo root on the feature branch.

## Prerequisites

- Dart SDK ^3.11.0 (3.13.x verified). No Flutter SDK needed.

## The behaviors (the #1588 harness tiers)

```sh
# Command level: inheritance + every mismatch dimension (real refactor,
# real dart test spawns counted through a logging wrapper)
dart test test/plugins/tdd/commands/bug_1652_refactor_make_post_state_test.dart

# Driver level: the record is written on make-green; write failure warns
dart test test/plugins/tdd/run_driver_1652_make_post_state_test.dart
```

Expected: `All tests passed!` for both.

## Regression scope

```sh
# The #1588 ledger contract must be untouched by the new record
dart test test/plugins/tdd/commands/bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart

# The driver + refactor command neighbors
dart test test/plugins/tdd/run_command_test.dart test/plugins/tdd/refactor_command_test.dart
```

Expected: `All tests passed!` for both.

## Static gates

```sh
dart analyze lib/src/plugins/tdd/services/make_post_state.dart \
             lib/src/plugins/tdd/commands/run_driver_core.dart \
             lib/src/plugins/tdd/commands/refactor_command.dart \
             test/plugins/tdd/commands/bug_1652_refactor_make_post_state_test.dart \
             test/plugins/tdd/run_driver_1652_make_post_state_test.dart
dart format --output=none --set-exit-if-changed lib/src/plugins/tdd/services/make_post_state.dart \
             lib/src/plugins/tdd/commands/run_driver_core.dart \
             lib/src/plugins/tdd/commands/refactor_command.dart
```

Expected: `No issues found!` and `0 changed`.

## What "fixed" looks like

- Forward shape: after a make-green, `specs/<feature>/tdd/make-post-state.json`
  exists with `lib`/`test` digests matching the tree; the next
  `--pass-batch` refactor prints the `issue #1652` inheritance line,
  spawns ZERO suites, exits 0, and appends a no-op cycle-log entry
  naming the make it inherited from.
- Drift: touch any file under `lib/` or `test/` after the make → the
  next `--pass-batch` refactor runs the full pipeline (suite spawns
  happen).
- `--full-reproof` or a flag-less standalone refactor → always the full
  pipeline, record or no record.
