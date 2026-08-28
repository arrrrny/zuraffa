# Test: test-harness-subprocess-deadlock

- **Slug**: test-harness-subprocess-deadlock
- **Result**: verified
- **Branch**: fix/test-harness-subprocess-deadlock

## Reproduction (from assessment)

`test/commands/*` subprocess tests (which spawn the AOT `zfa` binary through
`run_zfa_source.dart`'s `_runSupervised`) hung until the 2-minute per-test
timeout under `dart test` in the sandbox.

## Re-run result

- `dart analyze test/helpers/run_zfa_source.dart` → no issues.
- `test/commands/initialize_dart_inplace_test.dart` completes (no deadlock).
- Full default `dart test` suite: `All tests passed!` (1875 passed, 1 skipped,
  0 failures) — the subprocess CLI tests no longer time out.
