# RED Evidence — bug #1507 (re-captured pre-fix, this session)

Command: `dart test test/plugins/tdd/bug_1507_kernel_cache_cycle_start_test.dart`
(Dart SDK 3.13.2, macos_x64; production tree reverted to the pre-fix base
revision `20403f6d` — parent of the fix commit — while the committed
6-test suite was kept. The suite's counting shell script guarantees a
healthy green cycle: the retry machinery never fires, so any deletion must
come from a cycle-start sweep.)

Result: **6 failing / 0 passing — all for the RIGHT reason.**

> This capture supersedes the earlier 3-test one. The original red run
> predated C5 (liveness guard), C6 (project-cycle ownership guard) and C7
> (ancestor handling), so those behaviors had no red-phase evidence. All
> six tests now carry it.

```
00:00 +0: ... C1+C2+C3 (refactor): a HEALTHY green cycle deletes stale kernel
directories AND files and logs the reclaimed size [E]
  Expected: false
    Actual: <true>
  the leaked $TMPDIR/dart_test.kernel.* entries are DIRECTORIES — the sweep must
  match and delete them recursively (C1)

01:29 +0 -2: ... C4 (refactor): a kernel entry younger than the command start
survives the sweep (concurrent-runner guard preserved) [E]
  Expected: false
    Actual: <true>
  the stale kernel directory is swept (C1)

03:28 +0 -3: ... C2 (run): zfa tdd run sweeps stale kernel entries at cycle start —
run_command had NO kernel handling at all before the fix [E]
  Expected: false
    Actual: <true>
  zfa tdd run must sweep $TMPDIR/dart_test.kernel.* directories at cycle start
  (C1+C2) — out:
  zfa tdd run: feature 090-tdd-fixture — 3 behavior(s)
     suite baseline: dart test (once per run — issue #741)
  [run] B-001 gen -> ok
  ...
  run: feature=090-tdd-fixture result=complete pending=0 red=0 green=0 done=3

03:53 +0 -4: ... C5 (refactor): a kernel dir referenced by a LIVE process argv
survives the sweep — liveness guard, then swept once the holder exits [E]
  Expected: false
    Actual: <true>
  an unreferenced stale kernel dir is swept — out:
  ...
  refactor: feature=090-tdd-fixture outcome=clean applied=0

04:20 +0 -5: ... C6 (refactor): the project-local .dart_tool/test/ is left to its
active owner when another live tdd cycle holds the project [E]
  Expected: false
    Actual: <true>
  the ownership guard is scoped to the project cache only: the unreferenced stale
  TMPDIR kernel dir is still swept — out:
  ...
  refactor: feature=090-tdd-fixture outcome=clean applied=0

04:48 +0 -6: ... C7 (refactor): an ANCESTOR cycle marker does not block the child
cycle-start clear (`tdd run` spawns `tdd refactor` step children) [E]
  Expected: false
    Actual: <true>
  an ancestor marker is treated as this cycle, not a foreign owner — the project
  cache is still cleared — out:
  ...
  refactor: feature=090-tdd-fixture outcome=clean applied=0

04:48 +0 -6: Some tests failed.
```

## Why these failures pin the bug

1. **The stale `dart_test.kernel.*` DIRECTORY survives a healthy green
   refactor cycle** (C1) — the production sweep matched `entity is File`
   (the pre-fix `_clearDartTestKernelCache`) while the leaked entries are
   directories; the branch was dead code. No reclaim line was logged either.
2. **C4 fails on its C1 assertion, not on its guard** — the stale directory
   is not swept; the mtime-guard assertion is contract-pinning and only
   becomes observable once the sweep exists.
3. **`zfa tdd run` completes every step and leaves the stale entries
   untouched** (C2-run) — `run_command.dart` had no kernel handling at all,
   and the only pre-existing call site is reachable solely from the
   `ReproofFailureClass.infraRunner` retry path.
4. **C5 fails on `expect(freeDir.existsSync(), isFalse)`** — pre-fix
   *nothing* was deleted for directories, so the unreferenced stale dir
   survives. C5 was authored after the original 3-test capture and now
   carries its own red evidence here.
5. **C6 fails on the sweep-scope assertion** — pre-fix no cycle-start sweep
   runs at all (the project-local `.dart_tool/test/` clear itself lived only
   on the retry path), so the seeded TMPDIR entry is never reclaimed and
   neither guard exists.
6. **C7 fails on `expect(probe.existsSync(), isFalse)`** — for the same
   reason: with no cycle-start call in the pre-fix tree, the project cache
   is never cleared on a healthy cycle. Post-fix, C7 additionally pins that
   an *ancestor* marker (a `tdd run` parent that spawned this refactor step
   child) is treated as this cycle rather than a foreign owner.
