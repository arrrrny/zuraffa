# Bug Assessment — #1507: TMPDIR kernel cache leak (51 GB) — cleanup is a no-op

- **Slug**: 1507-tmpdir-kernel-cache-leak
- **Created**: 2026-09-11
- **Source**: bug report 1507 (provided in the task brief; phrased as GitHub
  issue #1507 on arrrrny/zuraffa)
- **Verdict**: valid
- **Severity**: critical (host disk exhaustion — Docker Desktop died of ENOSPC)

## Symptom

`zfa tdd` leaks `$TMPDIR/dart_test.kernel.*` directories without bound. The
reporter observed **51 GB / 869 dill files in ~80 minutes** (one
`dart_test.kernel.VSoGgt/`-style directory per `dart test` invocation, ~64 MB
every few seconds) until the host ran out of disk. The built-in cleanup
(`_clearDartTestKernelCache`) is a no-op against the leak, so a healthy TDD
loop — the one that actually leaks — never reclaims anything.

## Root cause (two layers, confirmed against the tree)

1. **Wrong type test — dead code.** The TMPDIR sweep matched
   `entity is File` (`lib/src/plugins/tdd/commands/refactor_command.dart`,
   pre-fix lines 988-1025), but the leaked entries are DIRECTORIES
   (`dart_test.kernel.<rand>/` full of `.dill` files created by
   `Directory.systemTemp.createTempSync('dart_test.kernel.')` in
   package:test's VM compiler). `entity is File` is never true for them, so
   the branch never fired. The `lastModified()` call the old code reached only
   compiles because the type promotion to `File` exposes it — a `Directory`
   has no such instance method.
2. **Wrong scope — the only call site is the infra-retry path.** The sole
   caller is `refactor_command.dart:613`, reached solely on the
   `ReproofFailureClass.infraRunner` retry path (issue #1333 machinery). A
   healthy cycle produces no infra failure, so the normal
   `zfa tdd run` → refactor cycle never clears anything. `run_command.dart`
   has no kernel handling at all.

## Reproduction

```bash
zfa tdd run <feature> --timeout 180
# Watch the leak:
du -sh "$TMPDIR"/dart_test.kernel.*
# Grows ~64 MB / few seconds, never cleaned up
```

Unit-level reproduction (this session): see
`tdd/red-evidence.md` — the new test file fails 3/3 pre-fix for exactly the
reasons above.

## Constraints honored

- Fix confined to the kernel cache cleanup in `refactor_command.dart` and
  `run_command.dart`; no test-runner semantics, state machine, or loop logic
  touched.
- Must match `Directory` as well as `File`, delete recursively.
- Must be called at the start of every TDD cycle (both commands), not only on
  infra-retry.
- Must log what was reclaimed: `cleared N stale kernel dir(s), freed X MB`.
- Must not break concurrent runners — the existing `commandStartedAt` guard is
  preserved; a liveness guard was ADDED (see `fix.md`) because the mtime guard
  alone cannot distinguish a stale kernel dir from the live outer dart test
  runner's kernel in the repo's own in-process test fleet.
- Related tooling already carrying the correct shell-level `rm -rf` shape:
  `tools/run-tdd-tests.sh`, `tools/run_tests_chunked.sh`,
  `tools/run_chunks_range.sh`.

## Remediation

Applied (see `fix.md`): shared top-level `clearDartTestKernelCache` in
`refactor_command.dart` (Directory+File match, recursive delete, reclaimed-size
log, `commandStartedAt` guard preserved, liveness guard added), called at the
start of every refactor cycle, every run cycle, and retained on the
infra-retry path.
