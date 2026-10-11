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
//
// ORDERING HAZARD — do not run a parallel lane over suites that nest
// CliRunner dispatches inside this window: `_withDir` takes CWD→EXIT
// while `CliRunner.runCapturing` takes EXIT→CWD (its `-C` window), a
// classic hold-and-wait inversion. The old fixed 30-second stale-break
// was accidentally escaping those deadlocks (at the cost of breaking
// LIVE holders — the rotating CI reds); heartbeat staleness removed the
// accidental escape, so a parallel lane would deadlock for real. The
// dart_core lane is serial for exactly this reason (plus the wider
// process-global CWD redirection hazard) — see .github/workflows/ci.yaml.
//
// Liveness protocol (kept in sync with `CliRunner._acquireCwdLock`): the
// holder heartbeats the lock file every few seconds, and an acquirer
// breaks it only when the file goes COLD — proof the holder died
// mid-window (a killed isolate never runs its `finally`, so the file
// would otherwise leak and block every later window in the process).
// The former fixed 30-second break had exactly one failure mode in each
// direction: it broke LIVE holders whose window outlived 30s under load
// (the rotating CI reds), and any ceiling long enough to fix that made
// waiters hit their own test timeouts first.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

abstract final class CwdMutex {
  /// MUST stay byte-identical to CliRunner's `_cwdLockFile`: one shared
  /// file is what makes raw test chdir windows mutually exclusive with
  /// the runner's own `-C` windows.
  static final File _lockFile = File(
    p.join(Directory.systemTemp.path, 'zfa_cwd_lock_$pid.lock'),
  );

  /// How long the lock file may go without a heartbeat before it counts
  /// as holder death. MUST stay in sync with
  /// `CliRunner.staleCwdLockAfter`.
  static const Duration staleAfter = Duration(seconds: 30);

  static const Duration _heartbeatEvery = Duration(seconds: 5);

  static Timer? _heartbeat;

  /// Acquires the cross-isolate CWD lock. Exclusive-create
  /// (`File.createSync(exclusive: true)`) is the atomic serialization
  /// point; it works across isolates AND processes. A held lock is broken
  /// only when its heartbeat went cold (holder death), never while the
  /// holder is alive.
  static Future<void> acquire() async {
    var breakAttempts = 0;
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
        // Cold file: the holder died mid-window. Break and retry.
        if (++breakAttempts > 3) {
          // Degraded mode (mirrors CliRunner's valve): the cold file
          // survived three break rounds (e.g. a foreign user's file this
          // user cannot delete) — proceed without exclusivity instead of
          // spinning forever.
          stderr.writeln(
            'zfa test: warning: stale CWD lock (${_lockFile.path}) could '
            'not be broken; continuing WITHOUT exclusion — concurrent '
            'suites may interleave their working directories.',
          );
          return;
        }
        try {
          _lockFile.deleteSync();
        } on FileSystemException {
          // Unbreakable — the bounded break counter above degrades after
          // three failed rounds; the retry-create below loses the break
          // race and the loop re-checks.
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
