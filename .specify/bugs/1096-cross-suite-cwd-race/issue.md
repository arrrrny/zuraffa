# Bug 1096 — cross-suite `Directory.current` race in `CliRunner._withDirectory`

- **Severity:** medium (flake)
- **Reported by:** CI observation (GitHub issue #1096)
- **Status:** fixed on branch `fix/1096-cross-suite-cwd-race`

## Symptom

`dart test test/plugins/service/` flakes: the service verdict tests
(`service_create_json_verdict_test.dart` and siblings that drive the CLI with
`-C <temp>`) fail intermittently when run with sibling suites, while the same
file passes green in isolation (4/4). The whole suite also passed 53/53 twice
the same day.

## Root cause

`CliRunner._withDirectory` (lib/src/cli/cli_runner.dart) mutates the
process-wide `Directory.current` for `-C` invocations and restores it after
the invocation. The `_active` re-entrancy guard only protects one
`CliRunner` instance. `dart test` runs suites as concurrent isolates of one
VM, so two suites each driving their own runner with `-C <temp>` race on the
process CWD:

```text
suite A: saved = <repo>; chdir -> tempA       (window open)
suite B: saved = tempA (!); chdir -> tempB    (window open — overlap)
suite A: relative writes resolve against tempB; restores <repo>
suite B: restores tempA — process left in the wrong root
```

Between chdir and restore another suite can chdir elsewhere (writes land in
or resolve from the wrong root) or delete its temp dir (the documented
`PathNotFoundException` hazard: `Getting current working directory failed`).

Commands resolve output paths relative to `Directory.current` **at write
time** (e.g. `FileUtils.writeFile` with `outputDir: lib/src`), so a hijacked
CWD silently redirects artifacts while the verdict still reports the
intended path — the observed "ok:true but file missing from own workspace"
lie.

## Fix

Serialize the whole chdir window (capture `saved` → chdir → body → restore)
across isolates with an exclusive-create lock file keyed by PID
(`$TMPDIR/zfa_cwd_lock_<pid>.lock`):

- All dart-test suite isolates share the runner process's PID → they contend
  on one file → exactly the mutual exclusion needed.
- A spawned `zfa` CLI owns a private CWD in its own process → its own lock
  file → no cross-process contention and no parent/child deadlock.
- Suites that never pass `-C` never touch the lock → parallel execution of
  other suites is unaffected.
- Stale-lock handling: a waiter waits up to 30 s, then breaks the stale file
  once (holder died mid-window) and proceeds; release happens only after the
  restore so the next window captures a stable CWD.

## Repro notes

The natural flake is intermittent and was not reproduced in 3 consecutive
runs of `dart test test/plugins/service/` pre-fix. The deterministic repro
vehicles are the two regression tests added in
`test/commands/cli_runner_cwd_race_test.dart` (see `tdd/cycle-log.md`).

## Verification

See [tdd/verification.md](tdd/verification.md).
