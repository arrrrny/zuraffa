/// Cross-isolate serializer for cwd-dependent in-process CLI runs.
///
/// `Directory.current` is process-wide while `dart test` runs test files
/// as concurrent isolates in one VM (see cli_runner.dart's `_withDirectory`
/// notes). Every mock CLI test drives `runCapturing(['-C', tempDir, ...])`,
/// which temporarily repoints the process CWD at its fixture — two such
/// files running concurrently would write into each other's fixtures (the
/// mutation-audit baseline `dart test <files>` hit exactly this: the
/// receipt test's files landed in the gate test's tree).
///
/// Why not `File.lockSync`: dart:io uses POSIX fcntl record locks, which
/// are PER-PROCESS — two isolates of the same `dart test` process both
/// "acquire" instantly (verified empirically). `File.create(exclusive:
/// true)` is O_CREAT|O_EXCL — a true atomic filesystem operation — so it
/// excludes across isolates AND processes. A stale lock (crashed holder)
/// is broken after [staleAfter] so a dead holder can never wedge the
/// suite.
library;

import 'dart:async';
import 'dart:io';

class CwdGuard {
  static const _lockPath = '/tmp/.zfa_mock_cli_cwd.lockfile';

  /// A crashed holder's lock is stolen after this long.
  static const staleAfter = Duration(seconds: 45);

  /// Runs [body] while holding the exclusive cwd lock.
  static Future<T> exclusive<T>(Future<T> Function() body) async {
    final lockFile = File(_lockPath);
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    var acquired = false;
    while (!acquired) {
      try {
        // O_CREAT|O_EXCL: atomic across isolates and processes.
        await lockFile.create(exclusive: true);
        acquired = true;
      } on FileSystemException {
        _breakStaleLock(lockFile);
        if (DateTime.now().isAfter(deadline)) {
          throw TimeoutException('cwd guard: could not acquire $_lockPath');
        }
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    }
    try {
      return await body();
    } finally {
      try {
        await lockFile.delete();
      } catch (_) {
        // Already gone (stale breaker raced us) — fine.
      }
    }
  }

  /// Steals a lock whose holder is provably gone (mtime older than
  /// [staleAfter]).
  static void _breakStaleLock(File lockFile) {
    try {
      if (!lockFile.existsSync()) return;
      final age = DateTime.now().difference(lockFile.lastModifiedSync());
      if (age > staleAfter) {
        lockFile.deleteSync();
      }
    } catch (_) {
      // Racing another breaker — either way the retry loop handles it.
    }
  }
}
