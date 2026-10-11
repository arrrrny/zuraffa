# TDD test list — bug 1096 (cross-suite CWD race)

Behaviors that must exist before the fix is accepted. Each maps to a test in
`test/commands/cli_runner_cwd_race_test.dart`.

| # | Behavior | Test |
|---|----------|------|
| B1 | Two concurrent `-C` invocations in one process must never hold overlapping chdir windows (observable: while suite A's window is open, suite B's invocation must not have moved the process CWD) | `two concurrent invocations never hold overlapping chdir windows` |
| B2 | After concurrent `-C` invocations complete, the process CWD must be restored to its pre-call value | same test as B1 |
| B3 | Each concurrent invocation's artifact must land in its own workspace root (write isolation under relative-path resolution) | same test as B1 |
| B4 | Two isolates (dart-test suite topology) driving `-C` concurrently must keep every round's write in their own workspace and never observe an unresolvable/deleted process CWD | `two isolates driving -C concurrently keep their writes isolated (dart-test suite topology)` |

Non-behavioral constraints:

- Suites that never pass `-C` must not touch the lock (parallel execution of
  other suites unchanged).
- A spawned `zfa` CLI subprocess must never contend with its parent's lock
  (own PID → own lock file).
