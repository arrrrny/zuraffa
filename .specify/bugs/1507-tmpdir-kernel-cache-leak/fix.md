# Fix — bug #1507: TMPDIR kernel cache leak (cleanup is a no-op)

- **Branch**: `fix/1507-tmpdir-kernel-cache-leak`
- **Files changed (production)**: `lib/src/plugins/tdd/commands/refactor_command.dart`,
  `lib/src/plugins/tdd/commands/run_command.dart`,
  `lib/src/plugins/tdd/services/kernel_cache.dart` (new — the shared sweep; see
  the review-fixes round below). No test-runner semantics, state machine, or
  loop logic touched.

## Review-fixes round (2026-09-11)

Review findings from `zuraffa-review[bot]` and `coderabbitai[bot]` on PR #1515
were applied on top of the original fix:

- **F4** — the sweep moved out of `refactor_command.dart` into
  `lib/src/plugins/tdd/services/kernel_cache.dart`, so `run_command.dart` no
  longer imports a sibling command module to borrow a free function.
- **F1 / CR-2** — the liveness probe is now portable: Linux reads
  `/proc/<pid>/cmdline`, macOS shells to `ps -ww -Ao pid=,args=`; Windows has no
  portable probe and degrades to the `commandStartedAt` guard. This closes the
  "on macOS/Windows the guard does not exist, so the new directory deletion is
  worse than the pre-fix code" gap, and the inaccurate "strictly no worse"
  claim was removed from `tdd/verification.md` and the PR body.
- **CR-1** — the shared `<project>/.dart_tool/test/` cache is now only deleted
  when no other live TDD cycle owns the project. A best-effort per-project
  marker (`.dart_tool/zfa_tdd_cycle.pid`, pid presence) records the active
  cycle; a live foreign owner makes the sweep skip the project cache (the
  per-entry guards still protect concurrent runners' kernels), while an
  ancestor owner (the `tdd run` parent of a `tdd refactor` step child) is
  treated as this cycle so the child still clears its own cache.
- **F2 / CR-3** — the suite's stale-directory fixture uses the portable
  `touch -t [[CC]YY]MMDDhhmm[.SS]` stamp (the GNU-only `touch -d @<epoch>`
  silently failed on macOS) and fails loudly on a non-zero exit; the suite is
  tagged `@TestOn('linux || mac-os')` for the platforms where the argv probe
  exists.
- **F3** — the RED evidence was re-captured with all five tests (0 → 5
  failures), so C5 and C6 each carry red-phase evidence; see
  `tdd/red-evidence.md`.
- Nitpicks — the reclaim line is shape-agnostic
  (`cleared N stale kernel entr(ies), freed X MB`) and `_entrySize` no longer
  lets a vanished `File` skip its delete.

## The fix

### 1. `services/kernel_cache.dart` — the sweep itself

The private `_clearDartTestKernelCache` method became the shared top-level
`Future<void> clearDartTestKernelCache(String projectRoot, {required DateTime
commandStartedAt})` in the plugin's `services/` layer (so both commands share
one contract without a command→command import). Behavior:

- **Match `Directory` as well as `File`** and delete directories RECURSIVELY —
  the leaked entries are per-invocation directories of dill files. The
  pre-fix `entity is File` branch was dead code.
- **Reclaimed-size log**: when anything was cleared, one line is printed —
  `   cleared N stale kernel entr(ies), freed X MB` (bytes are summed before
  deletion: file length for files, a recursive walk for directories; a file
  that vanishes mid-walk only undercounts the report, the delete still runs).
- **`commandStartedAt` guard preserved** (issue #1333 contract): entries whose
  mtime is not before `commandStartedAt` may belong to a concurrent runner and
  are left untouched. The pre-fix `entity.lastModified()` reached through type
  promotion became `(await entity.stat()).modified` — `lastModified()` is an
  instance method on `File` only, so the directory match needs `stat()`.
- **Project cache ownership guard (new, review finding CR-1)**:
  `<project>/.dart_tool/test/` is shared by every cycle in a project, so it is
  deleted only when no other live TDD cycle owns the project. A best-effort
  pid-presence marker at `<project>/.dart_tool/zfa_tdd_cycle.pid` records the
  active cycle; a live foreign owner skips the project-cache deletion (with a
  one-line note) while the per-entry guards below keep protecting concurrent
  runners' kernels. A stale (dead-pid) marker never blocks the sweep, and an
  ANCESTOR marker is treated as this cycle (the `tdd run` parent that spawned
  this `tdd refactor` step child is blocked waiting, not using the cache, so
  it must not suppress the child's own cycle-start clear).
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
  `/proc/<pid>/cmdline`; on macOS, `ps -ww -Ao pid=,args=`; match the absolute
  kernel-dir path with the shared `_kernelDirInArgv` regex (handles both
  bare-path and `--flag=` prefixed argv elements). On Windows or on any error
  the set is empty and the `commandStartedAt` and ownership guards apply.
  Best-effort, never fatal.

### 2. `refactor_command.dart` — call it at cycle start

`_run` now sweeps immediately after capturing `commandStartedAt`, before the
feature resolution and the preflight suite:

```dart
await clearDartTestKernelCache(cwd, commandStartedAt: commandStartedAt);
```

The infra-retry call site (line ~613) is unchanged apart from the new
top-level name.

### 3. `run_command.dart` — cycle-start sweep (was absent entirely)

- `import '../services/kernel_cache.dart';`
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
