# Fix: test-harness-subprocess-deadlock

- **Slug**: test-harness-subprocess-deadlock
- **Branch**: fix/test-harness-subprocess-deadlock
- **Issue**: https://github.com/arrrrny/zuraffa/issues/549
- **Status**: applied

## Remediation applied

In `test/helpers/run_zfa_source.dart`, `_runSupervised` previously captured the
child `zfa` process's stdout/stderr through a **pipe** (`Process.start` +
`stdout`/`stderr` listeners). The AOT `zfa` executable deadlocks on a piped
stdout when spawned from `dart test` in this sandboxed environment, so the
subprocess-based CLI tests (`test/commands/*`) hung until their 2-minute
per-test timeout.

Changed the child to run inside a `sh -c` wrapper that redirects its
stdout/stderr to temp files (`> out 2> err`). After the process exits, the
helper reads the captured output back from those files. The explicit
kill-on-timeout safety is preserved (`Process.start` + `process.kill` on
timeout), and the shell wrapper quotes args containing spaces/special chars so
paths and flags survive. `Process.kill` is synchronous (returns `bool`), so the
`finally` block calls it directly without `.catchError`.

## Files changed

- `test/helpers/run_zfa_source.dart` — `_runSupervised` now redirects to files
  instead of piping.

## Verification

- `dart analyze test/helpers/run_zfa_source.dart` → no issues.
- `test/commands/*` subprocess tests (e.g. `initialize_dart_inplace`,
  `app_shell`) complete instead of timing out.
- Full default `dart test` suite passes (1875 passed, 1 skipped, 0 failures).
