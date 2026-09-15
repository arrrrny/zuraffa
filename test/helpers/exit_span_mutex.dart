// Issue #1096 family — the test-side half of the cross-isolate exitCode
// lock.
//
// `dart test` runs suites as concurrent isolates of ONE VM, and
// `dart:io exitCode` is process-wide. CliRunner serializes the
// PROCESS-GLOBAL `exitCode` write spans of `runCapturing` (the hermetic
// reset at dispatch, the dispatched-code snapshot, the final re-apply)
// through `_exitSpanLockFile` (lib/src/cli/cli_runner.dart, issue #1632);
// suites that dispatch through a BARE `CommandRunner` (no CliRunner —
// therefore no snapshot and no lock of their own) and read the global
// getter after the dispatch must serialize through the SAME lock file,
// or a sibling dispatch's reset/re-apply landing between this suite's
// command completion and its read clobbers the value the command
// produced (the #1632 `--concurrency=4` dart_core lane's skin-kit
// false exit-1).
//
// Acquire BEFORE the dispatch and release AFTER the read — the same
// span discipline the runner applies internally, so the two never
// overlap.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

abstract final class ExitSpanMutex {
  /// MUST stay byte-identical to CliRunner's `_exitSpanLockFile`: one
  /// shared file is what makes a bare-dispatch read span mutually
  /// exclusive with the runner's own reset/snapshot/re-apply spans.
  static final File _lockFile = File(
    p.join(Directory.systemTemp.path, 'zfa_exit_lock_$pid.lock'),
  );

  /// Acquires the cross-isolate exit-span lock, waiting up to 30 seconds
  /// for the current holder. Same protocol (exclusive-create + stale-lock
  /// break + degraded mode) as `CliRunner._acquireExitSpanLock` — keep
  /// the two in sync.
  static Future<void> acquire() async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    var lockBroken = false;
    while (true) {
      try {
        _lockFile.createSync(exclusive: true);
        return;
      } on FileSystemException {
        final expired = DateTime.now().isAfter(deadline);
        if (!expired) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
          continue;
        }
        if (!lockBroken) {
          // The holder most likely died mid-span (its isolate killed by
          // a test timeout). Break the stale lock once rather than stall
          // the rest of the run.
          lockBroken = true;
          try {
            _lockFile.deleteSync();
          } on FileSystemException {
            // Unbreakable — fall through to degraded mode below.
          }
          continue;
        }
        // Degraded mode: proceed without exclusivity instead of failing
        // every later dispatch forever.
        return;
      }
    }
  }

  /// Releases the lock. Best-effort, exactly like the runner's release:
  /// a lost release only costs the next holder one 30s wait before it
  /// breaks the stale file.
  static void release() {
    try {
      _lockFile.deleteSync();
    } on FileSystemException {
      // Already gone (another waiter broke a stale lock).
    }
  }
}
