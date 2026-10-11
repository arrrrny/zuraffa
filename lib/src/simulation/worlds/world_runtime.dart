/// The world runtime (spec 968, VISION §9): the simulated reality a
/// scenario executes in.
///
/// [WorldRuntime] binds a [WorldManifest] to its deterministic machinery:
///
/// - **virtual clock** — latency draws and backoff waits advance
///   simulated time; wall time is never read, never slept
/// - **latency model** — every invocation samples the touchpoint's
///   declared bands (fast/slow/timeout) from the seeded PRNG
/// - **failure schedule** — storms fire exactly where the manifest
///   declares (call-index windows), throwing the typed simulated
///   failures the #832 adapters already surface
///   (`SimulatedHttpException` / `SimulatedAuthException`) plus the
///   partial-write marker
/// - **golden corpus** — the fixture table the world serves per declared
///   contract method; `firebase-auth` touchpoints dispatch through the
///   #832 certified `FirebaseAuthAdapter` (worlds compose certified
///   mocks — the certification is the #832/#1001 machinery, never
///   self-graded)
/// - **play ledger** — every invocation recorded
///   (touchpoint/method/call/latency/band/virtual time/outcome); the
///   ordered ledger's digest is the run digest: same seed + same
///   manifest → identical digest (deterministic replay, #806 composes)
///
/// The runtime executes the manifest's behavior program via
/// [executeScenario]: `retry-sync` behaviors drive the shipped
/// `RetrySyncEngine` (temporal), `invoke` behaviors make single contract
/// invocations. Real-mode execution ([Binding.real]) runs the same
/// program against the direct harness — no latency injection, no storms,
/// no virtual clock — which is what the differential gate compares
/// against (#915 composes).
library;

import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import '../certified_worlds.dart';
import '../simulation_adapters.dart';
import 'failure_schedule.dart';
import 'latency_model.dart';
import 'retry_sync_engine.dart';
import 'virtual_clock.dart';
import 'world_manifest.dart';
import 'world_utils.dart';

/// The execution binding: the simulated world or the direct real-adapter
/// harness.
enum WorldBinding {
  /// The mock world: virtual clock, latency bands, failure storms.
  world,

  /// The real-adapter harness: direct corpus/adapter invocation with NO
  /// world semantics (no injected latency, no storms, real clock) — the
  /// production-shaped side of the differential gate.
  real,
}

/// One recorded invocation (the play ledger entry).
final class WorldPlay {
  const WorldPlay({
    required this.behavior,
    required this.touchpoint,
    required this.method,
    required this.call,
    required this.latencyMs,
    required this.band,
    required this.virtualMs,
    required this.outcome,
    required this.detail,
  });

  final String behavior;
  final String touchpoint;
  final String method;
  final int call;
  final int latencyMs;
  final String band;
  final int virtualMs;

  /// `ok` | `failure` | `partial`.
  final String outcome;
  final String detail;

  Map<String, dynamic> toJson() => {
    'behavior': behavior,
    'touchpoint': touchpoint,
    'method': method,
    'call': call,
    'latencyMs': latencyMs,
    'band': band,
    'virtualMs': virtualMs,
    'outcome': outcome,
    'detail': detail,
  };
}

/// The result of one scenario behavior execution.
final class BehaviorResult {
  const BehaviorResult({
    required this.behavior,
    required this.passed,
    required this.succeeded,
    required this.expectedRed,
    required this.attempts,
    required this.result,
    required this.failureLedger,
    required this.virtualElapsedMs,
    required this.detail,
  });

  final String behavior;

  /// Whether the behavior's outcome matched its declared expectation
  /// (`expect: green` landed green, `expect: red` landed red).
  final bool passed;

  /// The raw outcome (green = the operation succeeded).
  final bool succeeded;

  /// Whether the behavior was declared `expect: red` (the honest
  /// failure-surface class — the failure-storm behaviors).
  final bool expectedRed;

  final int attempts;
  final dynamic result;
  final List<String> failureLedger;
  final int virtualElapsedMs;
  final String detail;
}

/// Raised when the manifest's behavior program references an unknown
/// touchpoint or method — the world refuses to run a program that does
/// not match its declared contracts (never a silent no-op).
final class WorldProgramError implements Exception {
  const WorldProgramError(this.message);

  final String message;

  @override
  String toString() => 'WorldProgramError: $message';
}

/// The simulated reality for one world.
final class WorldRuntime {
  /// Create the runtime for [manifest] under [binding].
  ///
  /// [seedOverride] re-seeds the run (deterministic replay: the run
  /// receipt records the seed; replay re-executes with it).
  WorldRuntime(
    this.manifest, {
    this.binding = WorldBinding.world,
    int? seedOverride,
  }) : clock = VirtualClock(seedOverride ?? manifest.seed),
       _latency = LatencyModel(seed: (seedOverride ?? manifest.seed)),
       _authAdapter = _authAdapterFor(manifest);

  final WorldManifest manifest;
  final WorldBinding binding;
  final VirtualClock clock;
  final LatencyModel _latency;
  final FirebaseAuthAdapter? _authAdapter;

  final List<WorldPlay> _plays = [];
  final Map<String, int> _callCounts = {};

  /// The play ledger (append-only, ordered).
  List<WorldPlay> get plays => List.unmodifiable(_plays);

  /// Virtual milliseconds elapsed since the runtime was created.
  int get virtualElapsedMs => clock.elapsedMs;

  static FirebaseAuthAdapter? _authAdapterFor(WorldManifest manifest) {
    for (final t in manifest.touchpoints) {
      if (t.family == 'firebase-auth') {
        // The #832 certified auth world, zero-latency: the runtime's own
        // latency model owns timing.
        return FirebaseAuthAdapter(world: certifiedAuthWorld);
      }
    }
    return null;
  }

  /// Invoke [method] on [touchpoint] with [args], applying the world's
  /// latency, failure schedule, and corpus (or certified adapter). The
  /// invocation is recorded in the play ledger.
  Future<dynamic> invoke(
    String behaviorId,
    String touchpoint,
    String method, [
    Map<String, dynamic> args = const {},
  ]) async {
    final t = manifest.touchpointNamed(touchpoint);
    if (t == null) {
      throw WorldProgramError(
        'behavior "$behaviorId" targets unknown touchpoint "$touchpoint" '
        '--> fix: declare it in the External Dependencies table and '
        're-run `zfa simulate init ${manifest.scenario}`.',
      );
    }
    if (t.methods.where((m) => m.name == method).isEmpty) {
      throw WorldProgramError(
        'behavior "$behaviorId" targets method "$touchpoint.$method" the '
        'declared contract does not pin '
        '("${t.contract}") --> fix: align the behavior program with the '
        'declared contract.',
      );
    }
    final call = _nextCall(touchpoint, method);

    // 1. Latency: the world binding samples the bands and advances the
    //    virtual clock; the real binding injects nothing.
    final int latencyMs;
    final String bandLabel;
    if (binding == WorldBinding.world) {
      final bands = manifest.latency[touchpoint] ?? WorldLatencyBands.certified;
      final sample = _latency.sample(touchpoint, call, bands);
      latencyMs = sample.ms;
      bandLabel = sample.band.name;
      clock.advance(latencyMs);
    } else {
      latencyMs = 0;
      bandLabel = 'none';
    }

    // 2. Failure schedule (world binding only).
    if (binding == WorldBinding.world) {
      final storm = stormAt(manifest.storms, touchpoint, method, call);
      if (storm != null) {
        final failure = StormFailure(
          storm: storm,
          kind: StormFailure.kindOf(storm.failure),
        );
        switch (failure.kind) {
          case StormFailureKind.http:
            _plays.add(
              WorldPlay(
                behavior: behaviorId,
                touchpoint: touchpoint,
                method: method,
                call: call,
                latencyMs: latencyMs,
                band: bandLabel,
                virtualMs: clock.nowMs,
                outcome: 'failure',
                detail: 'storm ${storm.name}: ${failure.label}',
              ),
            );
            throw SimulatedHttpException(
              failure.httpStatus,
              _httpMethodFor(method),
              '/$touchpoint/$method',
              'failure storm ${storm.name} (${storm.kind})',
            );
          case StormFailureKind.auth:
            _plays.add(
              WorldPlay(
                behavior: behaviorId,
                touchpoint: touchpoint,
                method: method,
                call: call,
                latencyMs: latencyMs,
                band: bandLabel,
                virtualMs: clock.nowMs,
                outcome: 'failure',
                detail: 'storm ${storm.name}: ${failure.label}',
              ),
            );
            throw SimulatedAuthException(
              failure.authCode,
              'failure storm ${storm.name} (${storm.kind})',
            );
          case StormFailureKind.partial:
            final fixture = _deepCopy(
              manifest.corpusFixture(touchpoint, method),
            );
            if (fixture is Map<String, dynamic>) {
              fixture[kPartialWriteMarker] = true;
            }
            _plays.add(
              WorldPlay(
                behavior: behaviorId,
                touchpoint: touchpoint,
                method: method,
                call: call,
                latencyMs: latencyMs,
                band: bandLabel,
                virtualMs: clock.nowMs,
                outcome: 'partial',
                detail: 'storm ${storm.name}: partial-write marker',
              ),
            );
            return fixture;
          case StormFailureKind.unknown:
            _plays.add(
              WorldPlay(
                behavior: behaviorId,
                touchpoint: touchpoint,
                method: method,
                call: call,
                latencyMs: latencyMs,
                band: bandLabel,
                virtualMs: clock.nowMs,
                outcome: 'failure',
                detail: 'storm ${storm.name}: ${storm.kind}',
              ),
            );
            throw SimulatedHttpException(
              500,
              _httpMethodFor(method),
              '/$touchpoint/$method',
              'failure storm ${storm.name} (${storm.kind})',
            );
        }
      }
    }

    // 3. Serve the response.
    final result = await _serve(t, method, args);
    _plays.add(
      WorldPlay(
        behavior: behaviorId,
        touchpoint: touchpoint,
        method: method,
        call: call,
        latencyMs: latencyMs,
        band: bandLabel,
        virtualMs: clock.nowMs,
        outcome: 'ok',
        detail: 'served ${shapeOf(result)}',
      ),
    );
    return result;
  }

  Future<dynamic> _serve(
    WorldTouchpoint touchpoint,
    String method,
    Map<String, dynamic> args,
  ) async {
    // Corpus-scripted fixture-level faults (distinct from storms).
    final corpusFailure = manifest.corpusFailure(touchpoint.name, method);
    if (corpusFailure != null) {
      final kind = StormFailure.kindOf(corpusFailure);
      if (kind == StormFailureKind.http) {
        throw SimulatedHttpException(
          (corpusFailure['status'] as num?)?.toInt() ?? 500,
          _httpMethodFor(method),
          '/${touchpoint.name}/$method',
          'scripted corpus fault',
        );
      }
      if (kind == StormFailureKind.auth) {
        throw SimulatedAuthException(
          corpusFailure['code'] as String? ?? 'user-not-found',
          'scripted corpus fault',
        );
      }
    }

    // Certified-adapter composition: firebase-auth touchpoints dispatch
    // through the #832 certified FirebaseAuthAdapter (mocks the
    // framework certifies — never self-graded).
    if (touchpoint.family == 'firebase-auth' &&
        _authAdapter != null &&
        const {'signIn', 'signOut'}.contains(method)) {
      switch (method) {
        case 'signIn':
          final user = await _authAdapter.signIn(
            email: args['email'] as String? ?? 'ada@example.com',
            password: args['password'] as String? ?? 's3cret!',
          );
          return user.toJson();
        case 'signOut':
          await _authAdapter.signOut();
          return null;
      }
    }

    // Generic: serve the golden corpus fixture.
    return _deepCopy(manifest.corpusFixture(touchpoint.name, method));
  }

  /// Execute the manifest's behavior program, returning per-behavior
  /// results in declared order.
  Future<List<BehaviorResult>> executeScenario() async {
    _callCounts.clear();
    final results = <BehaviorResult>[];
    for (final behavior in manifest.behaviors) {
      results.add(await _executeBehavior(behavior));
    }
    return results;
  }

  Future<BehaviorResult> _executeBehavior(WorldBehavior behavior) async {
    final startMs = clock.elapsedMs;
    switch (behavior.driver) {
      case 'retry-sync':
        final engine = RetrySyncEngine(
          clock: clock,
          policy: RetryPolicy(
            maxAttempts: behavior.maxAttempts,
            backoffBaseMs: behavior.backoffBaseMs,
            backoffFactor: behavior.backoffFactor,
          ),
        );
        final outcome = await engine.sync(
          behavior.id,
          () => invoke(
            behavior.id,
            behavior.touchpoint,
            behavior.method,
            behavior.args,
          ),
        );
        return _check(
          behavior,
          succeeded: outcome.succeeded,
          attempts: outcome.attempts,
          result: outcome.result,
          failureLedger: [for (final f in outcome.failures) f.label],
          virtualElapsedMs: clock.elapsedMs - startMs,
          detail: outcome.stoppedBy == null
              ? 'retry-sync: ${outcome.attempts} attempts, '
                    '${outcome.failures.length} tolerated failures'
              : 'retry-sync stopped by ${outcome.stoppedBy} '
                    '(honest surface, no blind retry)',
        );
      case 'invoke':
      default:
        try {
          final result = await invoke(
            behavior.id,
            behavior.touchpoint,
            behavior.method,
            behavior.args,
          );
          final partial = result is Map && result[kPartialWriteMarker] == true;
          return _check(
            behavior,
            succeeded: !partial,
            attempts: 1,
            result: result,
            failureLedger: partial ? ['partial-write'] : const [],
            virtualElapsedMs: clock.elapsedMs - startMs,
            detail: partial
                ? 'partial-write marker surfaced (uncorrected)'
                : 'invocation ok',
          );
        } on SimulatedHttpException catch (e) {
          return _check(
            behavior,
            succeeded: false,
            attempts: 1,
            result: null,
            failureLedger: ['http-${e.statusCode}'],
            virtualElapsedMs: clock.elapsedMs - startMs,
            detail: 'http failure surfaced: ${e.statusCode}',
          );
        } on SimulatedAuthException catch (e) {
          return _check(
            behavior,
            succeeded: false,
            attempts: 1,
            result: null,
            failureLedger: ['auth-${e.code}'],
            virtualElapsedMs: clock.elapsedMs - startMs,
            detail: 'auth failure surfaced: ${e.code}',
          );
        }
    }
  }

  /// Apply the declared expectation: a `green` behavior passes when it
  /// succeeds; a `red` behavior (the failure-storm class) passes when it
  /// honestly lands red. Anything else is a red the world does not
  /// explain away.
  static BehaviorResult _check(
    WorldBehavior behavior, {
    required bool succeeded,
    required int attempts,
    required dynamic result,
    required List<String> failureLedger,
    required int virtualElapsedMs,
    required String detail,
  }) => BehaviorResult(
    behavior: behavior.id,
    passed: succeeded != behavior.expectRed,
    succeeded: succeeded,
    expectedRed: behavior.expectRed,
    attempts: attempts,
    result: result,
    failureLedger: failureLedger,
    virtualElapsedMs: virtualElapsedMs,
    detail: detail,
  );

  /// The deterministic run digest: SHA-256 over the canonical JSON of
  /// the play ledger (plus the world hash and seed — the digest names
  /// WHICH world and WHICH time model produced the plays).
  String get runDigest => crypto.sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'world': manifest.worldHash,
            'seed': manifest.seed,
            'binding': binding.name,
            'plays': [for (final play in _plays) canonical(play.toJson())],
          }),
        ),
      )
      .toString();

  int _nextCall(String touchpoint, String method) {
    final key = '$touchpoint.$method';
    final next = (_callCounts[key] ?? 0) + 1;
    _callCounts[key] = next;
    return next;
  }

  static String _httpMethodFor(String method) => switch (method) {
    'pull' || 'get' || 'fetch' || 'read' || 'list' => 'GET',
    'delete' || 'remove' => 'DELETE',
    'put' || 'update' => 'PUT',
    _ => 'POST',
  };

  static dynamic _deepCopy(dynamic value) {
    if (value is Map) {
      return {
        for (final e in value.entries) e.key.toString(): _deepCopy(e.value),
      };
    }
    if (value is List) return [for (final e in value) _deepCopy(e)];
    return value;
  }
}
