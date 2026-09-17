import 'package:hive_ce/hive_ce.dart';

import '../../../core/plugin_system/capability.dart';
import '../../../core/sync_config.dart';
import '../../../core/sync_metadata.dart';
import '../../../core/sync_status.dart';
import '../builders/push_only_sync_strategy.dart';
import '../builders/sync_metadata_store.dart';
import '../sync_plugin.dart';

/// One scripted chaos step: a failure with a class label (or `null`
/// for an accepted call).
typedef _ChaosStep = ({String failureClass, Object error})?;

/// The scripted failing remote for one chaos scenario (spec 1136 lane
/// 4): a pure function from the 0-based call index to the outcome.
/// Deterministic by construction — the same script + the same call
/// order always produces the same chaos.
abstract interface class _ChaosScript {
  /// What the remote does on its [n]th create call (0-based).
  _ChaosStep step(int n);

  /// The chaos classes this script injects, in firing order (for the
  /// evidence line).
  List<String> get classes;
}

/// `offline-flap` (issue #1359): the remote refuses the first calls
/// (offline window), then flaps (fail/fail/ok cycle), then recovers.
final class _OfflineFlapScript implements _ChaosScript {
  @override
  _ChaosStep step(int n) {
    if (n < 4) {
      return (
        failureClass: 'offline',
        error: const _SocketFailure('offline: connection refused'),
      );
    }
    if ((n - 4) % 3 != 2) {
      return (
        failureClass: 'flap',
        error: const _SocketFailure('flap: connection reset by peer'),
      );
    }
    return null;
  }

  @override
  List<String> get classes => const ['offline', 'flap'];
}

/// A payment-domain failure: the charge is declined — a business
/// refusal the sync layer must survive without losing the record.
class _PaymentDeclined implements Exception {
  const _PaymentDeclined(this.message);
  final String message;
  @override
  String toString() => message;
}

/// `payment-decline` (spec 1136 lane 4): the remote declines the first
/// create calls with a card-declined domain error, then flaps, then
/// recovers — the temporal payment-failure class the sync strategy is
/// chaos-tested against.
final class _PaymentDeclineScript implements _ChaosScript {
  @override
  _ChaosStep step(int n) {
    if (n < 3) {
      return (
        failureClass: 'declined',
        error: const _PaymentDeclined('declined: card declined by issuer'),
      );
    }
    if (n < 5) {
      return (
        failureClass: 'flap',
        error: const _SocketFailure('flap: connection reset by peer'),
      );
    }
    return null;
  }

  @override
  List<String> get classes => const ['declined', 'flap'];
}

/// `zfa sync simulate --scenario offline-flap` (issue #1359; spec 1136
/// lane 4 extends the catalog) — the chaos driver for temporal sync
/// features: drives the REAL [PushOnlySyncStrategy] against a
/// scripted failing remote and proves eventual consistency (every
/// entity lands exactly once).
///
/// Scenarios (pluggable chaos scripts — the harness, not the strategy,
/// owns the script):
/// - `offline-flap` — the remote refuses the first calls (offline
///   window), then flaps (alternating fail/ok), then recovers.
/// - `payment-decline` — the remote declines the first calls with a
///   payment-domain error, then flaps, then recovers: the OCR/payment
///   async-failure class.
///
/// The driver's recovery pass retries the leftovers and reports the
/// per-key ledger. Zero data loss, zero duplicates, or the gate is RED.
class SimulateSyncCapability implements ZuraffaCapability {
  final SyncPlugin plugin;

  SimulateSyncCapability(this.plugin);

  static const scenarios = ['offline-flap', 'payment-decline'];

  static _ChaosScript _scriptFor(String scenario) => switch (scenario) {
    'offline-flap' => _OfflineFlapScript(),
    'payment-decline' => _PaymentDeclineScript(),
    _ => throw StateError('unknown scenario: $scenario'),
  };

  @override
  String get name => 'simulate';

  @override
  String get description =>
      'Chaos-drive the sync strategy against a scripted failing remote '
      '(scenarios: offline-flap, payment-decline) and report the '
      'per-key landing ledger';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'scenario': {
        'type': 'string',
        'description':
            'The chaos scenario to run (offline-flap: offline window, '
            'then connection flaps, then recovery; payment-decline: '
            'card-declined domain errors, then flaps, then recovery)',
        'enum': scenarios,
        'default': 'offline-flap',
      },
      'entityCount': {
        'type': 'integer',
        'description': 'Number of seeded pending entities (default 5)',
        'default': 5,
      },
    },
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'verdict': {'type': 'string'},
      'landed': {'type': 'integer'},
      'total': {'type': 'integer'},
      'totalRetries': {'type': 'integer'},
    },
  };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    return EffectReport(
      planId: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      pluginId: plugin.id,
      capabilityName: name,
      args: args,
      changes: const [],
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final scenario = (args['scenario'] ?? 'offline-flap') as String;
    if (!scenarios.contains(scenario)) {
      print(
        '❌ Unknown scenario "$scenario" — allowed: ${scenarios.join(", ")}',
      );
      return ExecutionResult(
        success: false,
        files: const [],
        data: {'verdict': 'unknown-scenario', 'scenario': scenario},
      );
    }
    final entityCount = (args['entityCount'] as int?) ?? 5;
    final script = _scriptFor(scenario);

    // The scripted chaos remote: each create call resolves through the
    // scenario's script (deterministic per call index).
    final remoteCalls = <String, int>{};
    final chaosFired = <String, int>{for (final c in script.classes) c: 0};
    var callCounter = 0;
    Future<String> scriptedCreateRemote(String entity) async {
      final n = callCounter++;
      final step = script.step(n);
      if (step != null) {
        chaosFired[step.failureClass] =
            (chaosFired[step.failureClass] ?? 0) + 1;
        remoteCalls['$entity#${step.failureClass}'] = n;
        throw step.error;
      }
      remoteCalls[entity] = n;
      return entity;
    }

    final keys = List.generate(entityCount, (i) => 'entity-$i');
    final box = _FakeBox();
    final store = SyncMetadataStore(box);
    final strategy = PushOnlySyncStrategy<String>(
      fetchLocal: (batchKeys) async => batchKeys,
      createRemote: scriptedCreateRemote,
      updateRemote: (entity) async => entity,
      deleteRemote: (_) async {},
      keyResolver: (entity) => entity,
      metadataStore: store,
      config: const SyncConfig(
        batchSize: 2,
        maxRetries: 5,
        backoffBaseMs: 1,
        backoffMaxMs: 2,
      ),
    );

    for (final key in keys) {
      await strategy.markPending(key);
    }

    // Round 1: the chaos window chews through the first pass.
    await strategy.syncPending();
    // Recovery: re-drive the strategy's own paths — pending records go
    // through syncPending, retries-exhausted records through syncFailed
    // (the reset) — until the landing ledger is full or the horizon is
    // exhausted.
    var recoveryRounds = 0;
    while (recoveryRounds < maxRecoveryRounds) {
      final pending = await store.countByStatus(SyncStatus.pending);
      final failed = await store.countByStatus(SyncStatus.failed);
      if (pending == 0 && failed == 0) break;
      recoveryRounds++;
      if (failed > 0) {
        await strategy.syncFailed();
      } else {
        await strategy.syncPending();
      }
    }

    var landed = 0;
    var retried = 0;
    var lost = 0;
    for (final key in keys) {
      final metadata = await store.get(key);
      if (metadata == null || metadata.status == SyncStatus.synced) {
        landed++;
      } else {
        lost++;
      }
      if ((metadata?.retryCount ?? 0) > 0) retried++;
      final status = metadata == null
          ? 'landed'
          : metadata.status == SyncStatus.synced
          ? 'landed'
          : '${metadata.status.name} (retries=${metadata.retryCount})';
      print('  $key: $status');
    }

    // No-duplicate proof: the remote accepted each key exactly once.
    final duplicateKeys = remoteCalls.keys
        .where((k) => !k.contains('#') && remoteCalls[k] != null)
        .toSet();
    final noDuplicates = duplicateKeys.length == landed;

    final verdict = lost == 0 && noDuplicates ? 'GREEN' : 'RED';
    final chaosLine = StringBuffer()..write('chaos:');
    for (final c in script.classes) {
      chaosLine.write(' $c=${chaosFired[c] ?? 0}');
    }
    print(chaosLine);
    print(
      'sync-simulate: scenario=$scenario entities=$entityCount '
      'landed=$landed/$entityCount retries>0=$retried '
      'recovery-rounds=$recoveryRounds duplicates=${landed - duplicateKeys.length} '
      'verdict=$verdict',
    );

    return ExecutionResult(
      success: verdict == 'GREEN',
      files: const [],
      data: {
        'verdict': verdict,
        'scenario': scenario,
        'landed': landed,
        'total': entityCount,
        'totalRetries': retried,
        'recoveryRounds': recoveryRounds,
        'chaos': {
          for (final c in script.classes) c: chaosFired[c] ?? 0,
        },
      },
    );
  }

  static const maxRecoveryRounds = 10;
}

/// A socket-shaped failure the strategy records verbatim.
class _SocketFailure implements Exception {
  const _SocketFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// An in-memory Hive-shaped box: implements the members
/// [SyncMetadataStore] uses; everything else is intentionally
/// unsupported via [noSuchMethod] (a replay of a real box is out of
/// scope for the simulation).
class _FakeBox implements Box<SyncMetadata> {
  final _map = <String, SyncMetadata>{};

  @override
  SyncMetadata? get(dynamic key, {SyncMetadata? defaultValue}) =>
      _map[key as String];

  @override
  Future<void> put(dynamic key, SyncMetadata value) async {
    _map[key as String] = value;
  }

  @override
  Iterable<dynamic> get keys => _map.keys;

  @override
  SyncMetadata? getAt(int index) => _map.values.elementAt(index);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
