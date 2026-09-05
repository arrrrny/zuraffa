/// Spec 968 — the retry-with-backoff sync engine (U6; acceptance
/// criterion 1's demo temporal feature, A8/A9).
///
/// The engine's defining behaviors are temporal: what happens OVER TIME
/// (backoff waits advance the virtual clock, never wall time) and UNDER
/// FAILURE (network flaps retried within budget, auth expiry surfaced
/// honestly, partial writes repaired, budget exhaustion red).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/simulation/simulation_adapters.dart';
import 'package:zuraffa/src/simulation/worlds/failure_schedule.dart';
import 'package:zuraffa/src/simulation/worlds/retry_sync_engine.dart';
import 'package:zuraffa/src/simulation/worlds/virtual_clock.dart';

void main() {
  group('RetryPolicy.backoffMsFor (exponential backoff shape)', () {
    const policy = RetryPolicy(
      maxAttempts: 5,
      backoffBaseMs: 50,
      backoffFactor: 2.0,
    );
    test('wait_n = base * factor^(n-1)', () {
      expect(policy.backoffMsFor(1), 50);
      expect(policy.backoffMsFor(2), 100);
      expect(policy.backoffMsFor(3), 200);
      expect(policy.backoffMsFor(4), 400);
    });

    test('a non-positive factor degrades to constant waits', () {
      const broken = RetryPolicy(
        maxAttempts: 3,
        backoffBaseMs: 75,
        backoffFactor: 0,
      );
      expect(broken.backoffMsFor(1), 75);
      expect(broken.backoffMsFor(3), 75);
    });
  });

  group('A8: survives the network-flap storm within budget', () {
    test('retries through 503s and succeeds on a later attempt', () async {
      final clock = VirtualClock(968);
      const policy = RetryPolicy(
        maxAttempts: 3,
        backoffBaseMs: 50,
        backoffFactor: 2.0,
      );
      final engine = RetrySyncEngine(clock: clock, policy: policy);

      var calls = 0;
      final outcome = await engine.sync('sync-push', () async {
        calls++;
        if (calls <= 2) {
          throw const SimulatedHttpException(
            503,
            'POST',
            '/v1/sync',
            'network flap',
          );
        }
        return {'status': 'synced', 'count': 2};
      });

      expect(outcome.succeeded, isTrue);
      expect(outcome.attempts, 3);
      expect(outcome.failures, hasLength(2));
      expect(outcome.failures[0].label, 'http-503');
      expect(outcome.failures[0].atAttempt, 1);
      expect(outcome.failures[1].atAttempt, 2);
      expect(outcome.result, {'status': 'synced', 'count': 2});
      expect(outcome.stoppedBy, isNull);
    });

    test('backoff waits advance VIRTUAL time, never wall time', () async {
      final clock = VirtualClock(968);
      const policy = RetryPolicy(
        maxAttempts: 3,
        backoffBaseMs: 50,
        backoffFactor: 2.0,
      );
      final engine = RetrySyncEngine(clock: clock, policy: policy);

      final wall = Stopwatch()..start();
      var calls = 0;
      await engine.sync('sync-push', () async {
        calls++;
        if (calls < 3)
          throw const SimulatedHttpException(503, 'POST', '/', 'f');
        return {'ok': true};
      });
      wall.stop();

      // Virtual: 50ms + 100ms of backoff waits.
      expect(clock.elapsedMs, greaterThanOrEqualTo(150));
      // Wall: a full retry cycle in well under a second — no sleeping.
      expect(wall.elapsedMilliseconds, lessThan(500));
    });
  });

  group('A9: honest failure surfaces', () {
    test('auth expiry mid-flow short-circuits (no blind retry)', () async {
      final clock = VirtualClock(968);
      final engine = RetrySyncEngine(
        clock: clock,
        policy: const RetryPolicy(maxAttempts: 5, backoffBaseMs: 50),
      );
      final outcome = await engine.sync('auth-flow', () async {
        throw const SimulatedAuthException(
          'user-token-expired',
          'expired mid-flow',
        );
      });

      expect(outcome.succeeded, isFalse);
      expect(outcome.attempts, 1, reason: 'auth failures never retried');
      expect(outcome.stoppedBy, 'auth-user-token-expired');
      expect(outcome.failures.single.kind, 'auth');
    });

    test('partial writes are detected and repaired (one re-push)', () async {
      final clock = VirtualClock(968);
      final engine = RetrySyncEngine(
        clock: clock,
        policy: const RetryPolicy(maxAttempts: 3, backoffBaseMs: 50),
      );
      var calls = 0;
      final outcome = await engine.sync('partial-push', () async {
        calls++;
        if (calls == 1) {
          return <String, dynamic>{
            'status': 'partial',
            kPartialWriteMarker: true,
          };
        }
        return <String, dynamic>{'status': 'synced', 'count': 9};
      });

      expect(outcome.succeeded, isTrue);
      expect(outcome.repaired, isTrue);
      expect(outcome.attempts, 2);
      expect(outcome.failures.single.label, 'partial-write');
      expect(outcome.result, {'status': 'synced', 'count': 9});
    });

    test('a storm that outlasts the budget is an honest RED', () async {
      final clock = VirtualClock(968);
      final engine = RetrySyncEngine(
        clock: clock,
        policy: const RetryPolicy(maxAttempts: 3, backoffBaseMs: 50),
      );
      final outcome = await engine.sync(
        'endless-flap',
        () => throw Exception('transport'),
      );

      expect(outcome.succeeded, isFalse);
      expect(outcome.attempts, 3);
      expect(outcome.failures, hasLength(3));
      expect(outcome.stoppedBy, contains('budget-exhausted'));
    });

    test('an unrepaired partial write (repair disabled) is red', () async {
      final clock = VirtualClock(968);
      final engine = RetrySyncEngine(
        clock: clock,
        policy: const RetryPolicy(
          maxAttempts: 3,
          backoffBaseMs: 50,
          repairPartialWrites: false,
        ),
      );
      final outcome = await engine.sync('partial-push', () async {
        return <String, dynamic>{
          'status': 'partial',
          kPartialWriteMarker: true,
        };
      });

      expect(outcome.succeeded, isFalse);
      expect(outcome.repaired, isFalse);
      expect(outcome.stoppedBy, contains('repair disabled'));
    });
  });

  group('SyncOutcome accounting', () {
    test('virtualElapsedMs covers the full wait ladder', () async {
      final clock = VirtualClock(1);
      final engine = RetrySyncEngine(
        clock: clock,
        policy: const RetryPolicy(
          maxAttempts: 4,
          backoffBaseMs: 100,
          backoffFactor: 3.0,
        ),
      );
      var calls = 0;
      final outcome = await engine.sync('ladder', () async {
        calls++;
        if (calls < 4)
          throw const SimulatedHttpException(500, 'POST', '/', 'f');
        return {'done': true};
      });
      // Backoffs: 100 + 300 + 900 = 1300 virtual ms of waiting.
      expect(outcome.virtualElapsedMs, greaterThanOrEqualTo(1300));
      expect(outcome.attempts, 4);
    });
  });
}
