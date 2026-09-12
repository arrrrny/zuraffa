## Summary
`zfa tdd` leaks `$TMPDIR/dart_test.kernel.*` directories without bound: 51 GB /
869 dill files in ~80 minutes on the reporter's machine (one
`dart_test.kernel.VSoGgt/`-style directory per `dart test` invocation, ~64 MB
every few seconds) until Docker Desktop shut itself down from ENOSPC. The
built-in cleanup `_clearDartTestKernelCache` is a no-op against the leak, so
the healthy TDD loop — the one that actually leaks — never reclaims anything.

## Already tracked
This assessment was produced from the bug report supplied with the fix brief
(bug 1507). No separate GitHub issue fetch was required.

## Root cause (confirmed against the tree)

1. **Wrong type test — dead code.** The TMPDIR sweep matched
   `entity is File` (`lib/src/plugins/tdd/commands/refactor_command.dart`,
   pre-fix lines 988-1025), but the leaked entries are DIRECTORIES
   (`dart_test.kernel.<rand>/` full of `.dill` files — created by
   `Directory.systemTemp.createTempSync('dart_test.kernel.')` in package:test's
   VM compiler). `entity is File` is never true for them; the branch never
   fired.
2. **Wrong scope.** The only call site is `refactor_command.dart:613`, reached
   solely on the `ReproofFailureClass.infraRunner` retry path (issue #1333).
   The normal `zfa tdd run` → refactor cycle — the one that actually leaks —
   never clears anything, and `run_command.dart` has no kernel handling at all.

## Reproduction

```bash
zfa tdd run <feature> --timeout 180
# Watch the leak:
du -sh "$TMPDIR"/dart_test.kernel.*
# Grows ~64 MB / few seconds, never cleaned up
```

Observed: 51 GB, 869 files in `dart_test.kernel.VSoGgt/`. Docker Desktop shut
itself down from ENOSPC.

## Expected

- `$TMPDIR/dart_test.kernel.*` cleaned after every cycle (not just
  infra-retry).
- Cleanup matches directories (not just files) and deletes recursively.
- A long-running TDD loop has bounded, roughly flat temp-disk usage.
- The sweep logs what it reclaimed.
- Concurrent runners keep working (the `commandStartedAt` guard preserved).
