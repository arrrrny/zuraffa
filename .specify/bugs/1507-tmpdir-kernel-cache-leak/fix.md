# Fix — bug #1507: TMPDIR kernel cache leak (cleanup is a no-op)

- **Branch**: `fix/1507-tmpdir-kernel-cache-leak`
- **Files changed (production)**: `lib/src/plugins/tdd/commands/refactor_command.dart`,
  `lib/src/plugins/tdd/commands/run_command.dart` — nothing else. No test-runner
  semantics, state machine, or loop logic touched.

## The fix

### 1. `refactor_command.dart` — the sweep itself

The private `_clearDartTestKernelCache` method became the public top-level
`Future<void> clearDartTestKernelCache(String projectRoot, {required DateTime
commandStartedAt})` (top-level so `run_command.dart` can share it; the file is
already part of the plugin's import cluster, and `run_command.dart` already
imports a sibling command — `run_engine_command.dart`). Behavior:

- **Match `Directory` as well as `File`** and delete directories RECURSIVELY —
  the leaked entries are per-invocation directories of dill files. The
  pre-fix `entity is File` branch was dead code.
- **Reclaimed-size log**: when anything was cleared, one line is printed —
  `   cleared N stale kernel dir(s), freed X MB` (bytes are summed before
  deletion: file length for files, a recursive walk for directories; a file
  that vanishes mid-walk only undercounts the report, the delete still runs).
- **`commandStartedAt` guard preserved** (issue #1333 contract): entries whose
  mtime is not before `commandStartedAt` may belong to a concurrent runner and
  are left untouched. The pre-fix `entity.lastModified()` reached through type
  promotion became `(await entity.stat()).modified` — `lastModified()` is an
  instance method on `File` only, so the directory match needs `stat()`.
- **Project cache unchanged**: `<project>/.dart_tool/test/` is still deleted
  recursively (counted toward N and the freed bytes now).
- **Liveness guard (new, necessary)**: a kernel entry whose absolute path
  appears in ANY live process's argv is skipped. The dart test runner's own
  frontend-server child holds `--output-dill=<tmp>/dart_test.kernel.<rand>/output.dill`
  for the whole invocation. Without this guard, sweeping at cycle start inside
  a process nested under a live `dart test` — which is exactly the repo's own
  in-process test fleet — deleted the OUTER runner's kernel mid-run and its
  loader crashed at close (`PathNotFoundException` copying
  `.dart_tool/test/incremental_kernel.*` back) — every in-process TDD test
  file exited 255 with all tests passing (measured: bug_1333 went from exit 0
  on master to exit 255 without this guard; the new sweep made the pre-fix
  accidental protection — files-only matching never touched the live
  directory — disappear). Implementation: on Linux, read
  `/proc/<pid>/cmdline` and match the absolute kernel-dir path with
  `_kernelDirInArgv` (handles both bare-path and `--flag=` prefixed argv
  elements); elsewhere or on any error the set is empty and only the
  `commandStartedAt` guard applies. Best-effort, never fatal.

### 2. `refactor_command.dart` — call it at cycle start

`_run` now sweeps immediately after capturing `commandStartedAt`, before the
feature resolution and the preflight suite:

```dart
await clearDartTestKernelCache(cwd, commandStartedAt: commandStartedAt);
```

The infra-retry call site (line ~613) is unchanged apart from the new
top-level name.

### 3. `run_command.dart` — cycle-start sweep (was absent entirely)

- `import 'refactor_command.dart' show clearDartTestKernelCache;`
- `final commandStartedAt = DateTime.now();` captured at the top of `_run`
  (before any lane spawns).
- The sweep runs right after feature resolution and BEFORE the dependency
  override preflight, the cert gate, and any lane step:

```dart
await clearDartTestKernelCache(
  projectRoot,
  commandStartedAt: commandStartedAt,
);
```

## Why the fix bounds the leak

Every TDD cycle now opens with a sweep that reclaims every `dart_test.kernel.*`
entry left by DEAD dart test invocations (all of them older than
`commandStartedAt` in the sequential-step production topology). Entries younger
than `commandStartedAt` (this cycle's own in-flight children, concurrent
runners') are preserved by the guards. The kernel dirs the sweep cannot reclaim
are precisely the ones still in use — there is no leak left, only live caches.

## Verification

See `test.md` and `tdd/verification.md` — red→green evidence, targeted suites,
and the chunked fast-suite run are recorded there from this session's actual
runs.
