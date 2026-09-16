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
//
// Liveness protocol (kept in sync with `CliRunner._acquireExitSpanLock`):
// the holder heartbeats the lock file every few seconds, and an acquirer
// breaks it only when the file goes COLD — proof the holder died
// mid-span (a killed isolate never runs its `finally`). The former fixed
// 30-second break broke LIVE holders whose span outlived 30s under load;
// any ceiling long enough to fix that made waiters hit their own test
// timeouts first.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

abstract final class ExitSpanMutex {
  /// MUST stay byte-identical to CliRunner's `_exitSpanLockFile`: one
  /// shared file is what makes a bare-dispatch read span mutually
  /// exclusive with the runner's own reset/snapshot/re-apply spans.
  static final File _lockFile = File(
    p.join(Directory.systemTemp.path, 'zfa_exit_lock_$pid.lock'),
  );

  /// How long the lock file may go without a heartbeat before it counts
  /// as holder death. MUST stay in sync with
  /// `CliRunner.staleExitSpanLockAfter`.
  static const Duration staleAfter = Duration(seconds: 30);

  static const Duration _heartbeatEvery = Duration(seconds: 5);

  static Timer? _heartbeat;

  /// Acquires the cross-isolate exit-span lock. Exclusive-create is the
  /// atomic serialization point; a held lock is broken only when its
  /// heartbeat went cold (holder death), never while the holder is alive.
  static Future<void> acquire() async {
    while (true) {
      try {
        _lockFile.createSync(exclusive: true);
        _startHeartbeat();
        return;
      } on FileSystemException {
        final age = _lockAge();
        if (age != null && age < staleAfter) {
          // Held by a live holder — wait for its release.
          await Future<void>.delayed(const Duration(milliseconds: 20));
          continue;
        }
        // Cold file: the holder died mid-span. Break and retry.
        try {
          _lockFile.deleteSync();
        } on FileSystemException {
          // Unbreakable — the retry-create below loses the break race
          // and the loop re-checks.
        }
        try {
          _lockFile.createSync(exclusive: true);
          _startHeartbeat();
          return;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      }
    }
  }

  /// Releases the lock (and the heartbeat). Best-effort: a lost release
  /// self-heals when the file goes cold and the next acquirer breaks it.
  static void release() {
    _heartbeat?.cancel();
    _heartbeat = null;
    try {
      _lockFile.deleteSync();
    } on FileSystemException {
      // Already gone (another waiter broke a stale lock).
    }
  }

  static void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_heartbeatEvery, (_) {
      try {
        _lockFile.setLastModifiedSync(DateTime.now());
      } on FileSystemException {
        // The waiter's break-race deleted the file — best-effort tick.
      }
    });
  }

  static Duration? _lockAge() {
    try {
      return DateTime.now().difference(_lockFile.lastModifiedSync());
    } on FileSystemException {
      return null; // vanished between the probe and this stat — retry
    }
  }
}
