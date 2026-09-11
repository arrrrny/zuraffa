# RED Evidence — bug #1507 (captured pre-fix, this session)

Command: `dart test test/plugins/tdd/bug_1507_kernel_cache_cycle_start_test.dart`
(Dart SDK 3.13.3, tree at `fix/1507-tmpdir-kernel-cache-leak` before the fix;
the suite's counting shell script guarantees a healthy green cycle — the retry
machinery never fires, so any deletion must come from a cycle-start sweep.)

Result: **3 failing / 0 passing — all for the RIGHT reason.**

```
00:01 +0 -1: ... C1+C2+C3 (refactor): a HEALTHY green cycle deletes stale kernel
directories AND files and logs the reclaimed size [E]
  Expected: false
    Actual: <true>
  the leaked $TMPDIR/dart_test.kernel.* entries are DIRECTORIES — the sweep must
  match and delete them recursively (C1)

00:02 +0 -2: ... C4 (refactor): a kernel entry younger than the command start
survives the sweep (concurrent-runner guard preserved) [E]
  Expected: false
    Actual: <true>
  the stale kernel directory is swept (C1)

00:08 +0 -3: ... C2 (run): zfa tdd run sweeps stale kernel entries at cycle start —
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

Some tests failed.
```

## Why these failures pin the bug

1. **The stale `dart_test.kernel.*` DIRECTORY survives a healthy green
   refactor cycle** — the production sweep matched `entity is File`
   (refactor_command.dart:1009 pre-fix) while the leaked entries are
   directories; the branch was dead code. No reclaim line was logged either
   (nothing was ever reclaimed).
2. **`zfa tdd run` completes all 12 steps and leaves the stale entries
   untouched** — `run_command.dart` had no kernel handling at all, and the
   only pre-existing call site (refactor_command.dart:613) is reachable solely
   from the `ReproofFailureClass.infraRunner` retry path.
3. The C4 test failed on its C1 assertion (the stale directory is not swept);
   its guard assertion (the future-mtime file survives) is contract-pinning
   and only becomes observable once the sweep exists.
