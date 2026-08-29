import 'dart:async';

import 'cancellation.dart';
import 'idempotency_cache.dart';
import 'introspection.dart';
import 'kernel_config.dart';
import 'mission.dart';
import 'mission_coalescer.dart';
import 'mission_event.dart';
import 'partial_salvage.dart';

/// Signature of the executor that runs a single mission to completion.
/// Returns the terminal [MissionOutcome].
///
/// Multi-isolate extension point (FR-009): override this with a
/// `SendPort`-proxied implementation to run missions in worker isolates.
typedef MissionExecutor =
    Future<MissionOutcome> Function(
      Mission mission,
      CoalescingGroup group,
      CancelToken cancelToken,
    );

/// The agent kernel — coordinates mission coalescing, cancellation, and
/// partial-salvage (issue #388).
///
/// ## Single-Isolate Assumption (FR-009)
///
/// This kernel operates within a single Dart isolate. All missions,
/// coalescing groups, and resource handles live in the same isolate's
/// memory. Concurrency is cooperative (async/await on the event loop),
/// not parallel. For multi-isolate pool support, override
/// [MissionExecutor] with an implementation that proxies work over
/// `SendPort`/`ReceivePort` — the kernel's coordination logic is
/// unchanged.
class AgentKernel {
  AgentKernel({
    KernelConfig config = const KernelConfig(),
    MissionExecutor? executor,
    PartialSalvager? salvager,
  }) : _config = config,
       _salvager = salvager ?? PartialSalvager(),
       _executor = executor ?? _defaultExecutor {
    _introspection = Introspection(
      coalescingWindow: config.coalescingWindow,
      activeGroups: _groups,
    );
    _cache = IdempotencyCache(
      ttl: config.idempotencyTtl,
      enabled: config.idempotencyEnabled,
    );
  }

  final KernelConfig _config;
  final PartialSalvager _salvager;
  final MissionExecutor _executor;
  late final Introspection _introspection;
  late final IdempotencyCache _cache;

  /// Canonical-key → active coalescing group.
  final Map<String, CoalescingGroup> _groups = <String, CoalescingGroup>{};

  /// Mission-id → canonical-key (for cancellation lookup by id).
  final Map<String, String> _missionIdToKey = <String, String>{};

  /// Submits a mission. If an active coalescing group exists for the
  /// mission's key, the caller subscribes to that group's event stream
  /// and receives the same events. Otherwise, a new group is created
  /// and the mission executes once (FR-001, FR-002).
  ///
  /// If idempotency is enabled and a cached outcome exists for the key,
  /// it is returned immediately without re-execution (FR-007).
  Future<MissionOutcome> submit(
    Mission mission, {
    void Function(MissionEvent event)? onEvent,
  }) async {
    final cached = _cache.lookup(mission.key);
    if (cached != null) {
      mission.outcome = cached;
      mission.status = MissionStatus.completed;
      onEvent?.call(MissionEventCompleted(mission.id, cached));
      return cached;
    }

    final canonical = mission.key.canonical;
    final existing = _groups[canonical];
    if (existing != null) {
      existing.addSubscriber(mission.callerId);
      _missionIdToKey[mission.id] = canonical;
      final sub = existing.events.listen(onEvent ?? (_) {});
      try {
        return await existing.done;
      } finally {
        await sub.cancel();
      }
    }

    // New coalescing group — execute once.
    final group = CoalescingGroup(mission);
    group.addSubscriber(mission.callerId);
    _groups[canonical] = group;
    _missionIdToKey[mission.id] = canonical;

    final sub = group.events.listen(onEvent ?? (_) {});
    final cancelToken = CancelToken(
      gracePeriod: _config.cancellationGracePeriod,
    );
    group.cancelToken = cancelToken;

    try {
      final execOutcome = await _executor(mission, group, cancelToken);
      // If cancel() ran first, the group is already completed with the
      // salvaged outcome — use that. Otherwise, complete with the
      // executor's outcome.
      if (group.isCompleted) {
        // Cancellation completed the group; return the salvaged outcome.
        final salvaged = group.mission.outcome!;
        _cache.store(mission.key, salvaged);
        return salvaged;
      }
      group.complete(execOutcome);
      _cache.store(mission.key, execOutcome);
      return execOutcome;
    } catch (e, st) {
      final outcome = OutcomeFailed(e, st);
      group.complete(outcome);
      _cache.store(mission.key, outcome);
      return outcome;
    } finally {
      await sub.cancel();
      await group.close();
      _groups.remove(canonical);
      _missionIdToKey.remove(mission.id);
    }
  }

  /// Cancels a mission by id and returns the salvaged result (FR-003, FR-004,
  /// FR-005, FR-006).
  ///
  /// Cancelling the leading mission completes the whole coalescing group with
  /// a `cancelled_partial` outcome; all subscribers (original + coalesced)
  /// receive that salvaged outcome. Per-subscriber policies (continue /
  /// escalate / serve-partials) are not yet wired up — see issue #388.
  Future<MissionOutcome> cancel(String missionId) async {
    final canonical = _missionIdToKey[missionId];
    if (canonical == null) {
      throw StateError('Mission not found: $missionId');
    }
    final group = _groups[canonical];
    if (group == null) {
      throw StateError('Mission not active: $missionId');
    }

    final token =
        group.cancelToken ??
        CancelToken(gracePeriod: _config.cancellationGracePeriod);

    // Salvage + complete the group synchronously BEFORE triggering
    // disposal. This ensures [submit] sees the salvaged outcome when
    // it resumes after the executor returns (the executor unblocks the
    // moment the disposal race starts, before this method runs its
    // post-disposal salvage).
    if (!group.isCompleted) {
      final salvagedOutcome = _salvager.salvage(group.mission);
      group.complete(salvagedOutcome);
    }

    // Trigger the grace-period disposal race. The executor's
    // `await cancelToken.onSettled` resolves when this completes.
    await runCancellation(token, group.handles);

    _cache.store(group.mission.key, group.mission.outcome!);
    return group.mission.outcome!;
  }

  /// Returns introspection data (FR-008).
  IntrospectionSnapshot introspect() => _introspection.snapshot();

  /// Active coalescing groups (canonical-key → group).
  Map<String, CoalescingGroup> get activeGroups =>
      Map<String, CoalescingGroup>.unmodifiable(_groups);

  /// Idempotency cache (exposed for testing).
  IdempotencyCache get idempotencyCache => _cache;

  /// Default executor — runs a no-op mission that completes immediately
  /// with an empty [OutcomeCompleted]. Real workloads override
  /// [MissionExecutor] via the constructor.
  static Future<MissionOutcome> _defaultExecutor(
    Mission mission,
    CoalescingGroup group,
    CancelToken cancelToken,
  ) async {
    return OutcomeCompleted(null);
  }
}
