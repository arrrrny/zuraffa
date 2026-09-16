// The cross-isolate lock liveness protocol (issue #1632 family).
//
// CliRunner's CWD + exit-span locks and the test-side CwdMutex /
// ExitSpanMutex serialize process-global state across `dart test` suite
// isolates. Their stale-lock recovery used to be a fixed 30-second
// deadline, which failed in BOTH directions under the `--concurrency=4`
// dart_core lane:
//
//   - a LIVE holder whose window outlived 30s (a fixture-heavy dispatch
//     spawning real `pub get`/`dart test` children) got its lock broken
//     mid-window — two suites then interleaved process-global CWD /
//     exitCode writes (the rotating doctor/service/dream/theater/usecase
//     CI reds);
//   - any ceiling long enough to stop that made waiters hit their own
//     per-test timeouts first (a killed isolate leaks the lock file — its
//     `finally` never runs — so every later window in the process stalled).
//
// The protocol is now heartbeat staleness: the holder touches the file
// every few seconds; only a COLD file (holder death) is broken. These
// pins hold the two halves of the protocol together: recovery from a
// dead holder stays fast, and the staleness constants cannot drift apart
// between the duplicated implementations.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/cwd_mutex.dart';
import '../helpers/exit_span_mutex.dart';

void main() {
  group('lock liveness: a dead holder is recovered fast, live ones never '
      'broken', () {
    test('CwdMutex: a cold (heartbeat-dead) lock file does not block '
        'acquisition', () async {
      final lockFile = File(
        p.join(Directory.systemTemp.path, 'zfa_cwd_lock_$pid.lock'),
      );
      addTearDown(() {
        CwdMutex.release();
        if (lockFile.existsSync()) lockFile.deleteSync();
      });
      // The post-death shape: the holder died without releasing, so the
      // file exists with a frozen mtime.
      lockFile.parent.createSync(recursive: true);
      lockFile.createSync();
      lockFile.setLastModifiedSync(
        DateTime.now().subtract(const Duration(seconds: 40)),
      );

      // Must complete via the cold-break path in well under a second —
      // NOT spin for the 30s staleness window.
      final sw = Stopwatch()..start();
      await CwdMutex.acquire();
      sw.stop();
      expect(
        sw.elapsed,
        lessThan(const Duration(seconds: 5)),
        reason: 'a dead holder must be recovered immediately',
      );
      expect(lockFile.existsSync(), isTrue);
    });

    test('ExitSpanMutex: a cold (heartbeat-dead) lock file does not block '
        'acquisition', () async {
      final lockFile = File(
        p.join(Directory.systemTemp.path, 'zfa_exit_lock_$pid.lock'),
      );
      addTearDown(() {
        ExitSpanMutex.release();
        if (lockFile.existsSync()) lockFile.deleteSync();
      });
      lockFile.parent.createSync(recursive: true);
      lockFile.createSync();
      lockFile.setLastModifiedSync(
        DateTime.now().subtract(const Duration(seconds: 40)),
      );

      final sw = Stopwatch()..start();
      await ExitSpanMutex.acquire();
      sw.stop();
      expect(
        sw.elapsed,
        lessThan(const Duration(seconds: 5)),
        reason: 'a dead holder must be recovered immediately',
      );
    });

    test('the staleness constants cannot drift between the duplicated '
        'implementations', () {
      // CwdMutex/ExitSpanMutex deliberately duplicate the runner's
      // protocol ("keep the two in sync") — these pins are the sync.
      expect(CliRunner.staleCwdLockAfter, CwdMutex.staleAfter);
      expect(CliRunner.staleExitSpanLockAfter, ExitSpanMutex.staleAfter);
      // The whole point of the rework: liveness heartbeats, not a fixed
      // ceiling. A seconds-scale staleness would re-break live holders
      // whose windows legitimately run minutes under the -j4 lane.
      for (final d in [
        CliRunner.staleCwdLockAfter,
        CliRunner.staleExitSpanLockAfter,
      ]) {
        expect(
          d,
          lessThan(const Duration(minutes: 1)),
          reason: 'staleness must track holder DEATH, not window length',
        );
      }
    });
  });
}
