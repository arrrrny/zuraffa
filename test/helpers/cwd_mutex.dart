// Issue #1096 family — the test-side half of the cross-isolate CWD lock.
//
// `dart test` runs suites as concurrent isolates of ONE VM, and
// `Directory.current` is process-wide. CliRunner serializes its `-C` chdir
// windows through `_cwdLockFile` (lib/src/cli/cli_runner.dart, issue
// #1096); suites that assign `Directory.current` DIRECTLY (a temp-dir
// sandbox in `setUp`, restored in `tearDown`) must serialize through the
// SAME lock file, or their windows overlap — the #1632 `--concurrency=4`
// dart_core lane turned that overlap into observed failures:
//
//   - a suite's `originalCwd` capture lands inside a sibling's open
//     window (so the restore targets a directory the sibling deletes →
//     `PathNotFoundException: Setting current working directory failed`),
//   - a sibling's window flips the process CWD mid-test, so the service
//     under test resolves the wrong tree.
//
// Acquire in `setUp` (before the chdir) and release in `tearDown` (after
// the restore — mirroring CliRunner's release-after-restore so the next
// holder always captures a stable CWD).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

abstract final class CwdMutex {
  /// MUST stay byte-identical to CliRunner's `_cwdLockFile`: one shared
  /// file is what makes raw test chdir windows mutually exclusive with
  /// the runner's own `-C` windows.
  static final File _lockFile = File(
    p.join(Directory.systemTemp.path, 'zfa_cwd_lock_$pid.lock'),
  );

  /// Acquires the cross-isolate CWD lock, waiting up to 30 seconds for
  /// the current holder. Same protocol (exclusive-create + stale-lock
  /// break + degraded mode) as `CliRunner._acquireCwdLock` — keep the two
  /// in sync.
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
          // The holder most likely died mid-window (its isolate killed
          // by a test timeout). Break the stale lock once rather than
          // stall the rest of the run.
          lockBroken = true;
          try {
            _lockFile.deleteSync();
          } on FileSystemException {
            // Unbreakable — fall through to degraded mode below.
          }
          continue;
        }
        // Degraded mode: proceed without exclusivity instead of failing
        // every later sandbox forever.
        return;
      }
    }
  }

  /// Releases the lock. Best-effort, exactly like the runner's release: a
  /// lost release only costs the next holder one 30s wait before it
  /// breaks the stale file.
  static void release() {
    try {
      _lockFile.deleteSync();
    } on FileSystemException {
      // Already gone (another waiter broke a stale lock).
    }
  }
}
