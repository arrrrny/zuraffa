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
// pins hold the protocol's three guarantees together: recovery from a
// dead holder stays fast, the staleness constants cannot drift apart
// between the duplicated implementations, and — the property the CI red
// wave hinged on — a LIVE holder is never broken while its heartbeat
// stays fresh.
library;

import 'dart:io';
import 'dart:isolate';

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

    test('CwdMutex: a LIVE holder is never broken while its heartbeat '
        'stays fresh', () async {
      final lockFile = File(
        p.join(Directory.systemTemp.path, 'zfa_cwd_lock_$pid.lock'),
      );
      Isolate? contender;
      addTearDown(() {
        contender?.kill(priority: Isolate.immediate);
        CwdMutex.release();
        if (lockFile.existsSync()) lockFile.deleteSync();
      });

      await CwdMutex.acquire(); // this isolate: the live holder
      final mtimeBefore = lockFile.lastModifiedSync();

      // The contender reports on the port ONLY if it ever wins the lock.
      // While this isolate's heartbeat keeps the file fresh it must never
      // win — the old fixed-30s protocol broke exactly this holder (the
      // rotating CI reds this rework exists to fix).
      final port = ReceivePort();
      final messages = <Object>[];
      port.listen((message) => messages.add(message as Object));
      contender = await Isolate.spawn(_contendCwdLock, port.sendPort);

      // Hold the window PAST the staleness horizon (+ margin): the waiter
      // must neither acquire nor delete the live holder's file.
      await Future<void>.delayed(
        CliRunner.staleCwdLockAfter + const Duration(seconds: 8),
      );
      expect(
        messages,
        isEmpty,
        reason:
            'a LIVE holder (fresh heartbeat) must never be broken — '
            'the waiter may not acquire while the holder keeps ticking',
      );
      expect(
        lockFile.existsSync(),
        isTrue,
        reason: "the holder's lock file must survive the waiter",
      );
      expect(
        lockFile.lastModifiedSync().isAfter(mtimeBefore),
        isTrue,
        reason: 'the heartbeat must have kept ticking through the hold',
      );

      // Release: the waiter must now proceed (well within a few seconds).
      CwdMutex.release();
      final sw = Stopwatch()..start();
      while (messages.isEmpty && sw.elapsed < const Duration(seconds: 10)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(messages, [
        'acquired',
      ], reason: 'once the holder releases, the waiter must acquire');
    }, tags: 'slow');
  });
}

/// The contending acquirer under test: reports `'acquired'` on [sp] iff
/// it ever wins the lock. While it waits it is parked in [CwdMutex]'s
/// 20 ms poll loop; the test kills the isolate at teardown.
void _contendCwdLock(SendPort sp) {
  CwdMutex.acquire().then((_) => sp.send('acquired'));
}
