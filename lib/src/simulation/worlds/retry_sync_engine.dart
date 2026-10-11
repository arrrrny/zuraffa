/// The demo temporal feature (spec 968, acceptance criterion 1): a
/// retry-with-backoff sync engine developed green entirely inside a
/// world.
///
/// [RetrySyncEngine] is the reference temporal feature: it syncs a batch
/// through a touchpoint operation with **retry with exponential
/// backoff**, and its defining behaviors are about *what happens over
/// time and under failure* — exactly the feature class single-touchpoint
/// mocks cannot express (issue #968's motivation).
///
/// Semantics:
/// - **backoff waits advance the VIRTUAL clock** — the engine never
///   sleeps wall time; a run that retries through a failure storm
///   completes in ~0 wall ms while recording the full simulated wait
/// - **failure classes**: HTTP failures (network flaps) and timeouts are
///   retried within the budget; **partial writes** are detected and
///   repaired (one re-push); **auth failures are never blindly retried**
///   — an expired session surfaces honestly (the "auth expiry
///   mid-flow" storm class)
/// - a storm that outlasts the retry budget is an honest RED outcome
///   with the complete failure ledger — worlds never hand out free
///   greens
library;

import 'dart:async';

import '../simulation_adapters.dart';
import 'failure_schedule.dart';
import 'virtual_clock.dart';
import 'world_utils.dart';

/// The retry policy: budget + exponential backoff shape.
final class RetryPolicy {
  const RetryPolicy({
    required this.maxAttempts,
    required this.backoffBaseMs,
    this.backoffFactor = 2.0,
    this.repairPartialWrites = true,
  });

  /// Total attempts allowed (the first try + retries).
  final int maxAttempts;

  /// First backoff wait in virtual ms: wait_n = base * factor^(n-1).
  final int backoffBaseMs;

  /// Exponential factor.
  final double backoffFactor;

  /// Whether partial-write markers are repaired by a re-push.
  final bool repairPartialWrites;

  /// The backoff wait (virtual ms) after the [attempt]th failure
  /// (1-based).
  int backoffMsFor(int attempt) {
    final factor = backoffFactor <= 0 ? 1.0 : backoffFactor;
    return backoffBaseMs * powInt(factor, attempt - 1);
  }
}

/// One recorded failure in the sync's ledger.
final class SyncFailure {
  const SyncFailure(this.kind, this.label, {required this.atAttempt});

  /// `http` | `timeout` | `partial` | `auth` | `unknown`.
  final String kind;

  /// The classified label (`http-503`, `auth-user-token-expired`,
  /// `partial-write`).
  final String label;

  /// The attempt (1-based) the failure occurred on.
  final int atAttempt;
}

/// The sync's outcome.
final class SyncOutcome {
  const SyncOutcome({
    required this.behavior,
    required this.succeeded,
    required this.attempts,
    required this.result,
    required this.failures,
    required this.virtualElapsedMs,
    required this.repaired,
    this.stoppedBy,
  });

  final String behavior;
  final bool succeeded;
  final int attempts;

  /// The final payload on success (the served fixture).
  final dynamic result;

  /// The complete failure ledger (every tolerated failure, in order).
  final List<SyncFailure> failures;

  /// Virtual ms the sync consumed (latency draws + backoff waits).
  final int virtualElapsedMs;

  /// Whether a partial write was detected and repaired.
  final bool repaired;

  /// The failure class that stopped an unsuccessful sync
  /// (`auth-user-token-expired`, `budget-exhausted`, ...).
  final String? stoppedBy;
}

/// The retry-with-backoff sync engine (the temporal demo feature).
final class RetrySyncEngine {
  RetrySyncEngine({required this.clock, required this.policy});

  /// The world's virtual clock: backoff waits advance it.
  final VirtualClock clock;

  final RetryPolicy policy;

  /// Sync [operation] (a touchpoint invocation) under the retry policy.
  Future<SyncOutcome> sync(
    String behavior,
    Future<dynamic> Function() operation,
  ) async {
    final startMs = clock.elapsedMs;
    final failures = <SyncFailure>[];
    var repaired = false;
    Object? lastError;

    for (var attempt = 1; attempt <= policy.maxAttempts; attempt++) {
      try {
        final result = await operation();

        // Partial-write detection: the write half-landed.
        if (result is Map && result[kPartialWriteMarker] == true) {
          failures.add(
            SyncFailure('partial', 'partial-write', atAttempt: attempt),
          );
          if (policy.repairPartialWrites) {
            // Repair: re-push once (the next loop iteration re-invokes).
            repaired = true;
            if (attempt < policy.maxAttempts) {
              _waitBackoff(attempt);
              continue;
            }
            return _outcome(
              behavior,
              succeeded: false,
              attempts: attempt,
              result: null,
              failures: failures,
              startMs: startMs,
              repaired: repaired,
              stoppedBy: 'partial-write (budget exhausted while repairing)',
            );
          }
          return _outcome(
            behavior,
            succeeded: false,
            attempts: attempt,
            result: null,
            failures: failures,
            startMs: startMs,
            repaired: false,
            stoppedBy: 'partial-write (repair disabled)',
          );
        }

        // Clean write: success with the complete ledger.
        return _outcome(
          behavior,
          succeeded: true,
          attempts: attempt,
          result: result,
          failures: failures,
          startMs: startMs,
          repaired: repaired,
          stoppedBy: null,
        );
      } on SimulatedAuthException catch (e) {
        // Auth-class failures surface honestly — never a blind retry
        // loop against an expired session (the auth-expiry storm class).
        failures.add(SyncFailure('auth', 'auth-${e.code}', atAttempt: attempt));
        return _outcome(
          behavior,
          succeeded: false,
          attempts: attempt,
          result: null,
          failures: failures,
          startMs: startMs,
          repaired: repaired,
          stoppedBy: 'auth-${e.code}',
        );
      } on SimulatedHttpException catch (e) {
        // Retryable class: network flaps and transport failures.
        lastError = e;
        failures.add(
          SyncFailure('http', 'http-${e.statusCode}', atAttempt: attempt),
        );
        if (attempt < policy.maxAttempts) {
          _waitBackoff(attempt);
          continue;
        }
      } catch (e) {
        // Other retryable transport errors.
        lastError = e;
        failures.add(SyncFailure('http', 'transport', atAttempt: attempt));
        if (attempt < policy.maxAttempts) {
          _waitBackoff(attempt);
          continue;
        }
      }
    }

    return _outcome(
      behavior,
      succeeded: false,
      attempts: policy.maxAttempts,
      result: null,
      failures: failures,
      startMs: startMs,
      repaired: repaired,
      stoppedBy: 'budget-exhausted (${lastError ?? "retry budget"})',
    );
  }

  /// Backoff: advance the VIRTUAL clock (never sleep wall time).
  void _waitBackoff(int attempt) {
    clock.advance(policy.backoffMsFor(attempt));
  }

  SyncOutcome _outcome(
    String behavior, {
    required bool succeeded,
    required int attempts,
    required dynamic result,
    required List<SyncFailure> failures,
    required int startMs,
    required bool repaired,
    String? stoppedBy,
  }) => SyncOutcome(
    behavior: behavior,
    succeeded: succeeded,
    attempts: attempts,
    result: result,
    failures: [
      for (final f in failures)
        SyncFailure(f.kind, f.label, atAttempt: f.atAttempt),
    ],
    virtualElapsedMs: clock.elapsedMs - startMs,
    repaired: repaired,
    stoppedBy: stoppedBy,
  );
}
