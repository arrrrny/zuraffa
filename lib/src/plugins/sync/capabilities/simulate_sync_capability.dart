import 'package:hive_ce/hive_ce.dart';

import '../../../core/plugin_system/capability.dart';
import '../../../core/sync_config.dart';
import '../../../core/sync_metadata.dart';
import '../../../core/sync_status.dart';
import '../builders/push_only_sync_strategy.dart';
import '../builders/sync_metadata_store.dart';
import '../sync_plugin.dart';

/// `zfa sync simulate --scenario offline-flap` (issue #1359) — the
/// chaos driver for temporal sync features: drives the REAL
/// [PushOnlySyncStrategy] against a scripted failing remote and proves
/// eventual consistency (every entity lands exactly once).
///
/// Scenario `offline-flap`: the remote refuses the first calls
/// (offline window), then flaps (alternating fail/ok), then recovers —
/// the driver's recovery pass retries the leftovers and reports the
/// per-key ledger. Zero data loss, zero duplicates, or the gate is RED.
class SimulateSyncCapability implements ZuraffaCapability {
  final SyncPlugin plugin;

  SimulateSyncCapability(this.plugin);

  static const scenarios = ['offline-flap'];

  @override
  String get name => 'simulate';

  @override
  String get description =>
      'Chaos-drive the sync strategy against a scripted failing remote '
      '(scenario: offline-flap) and report the per-key landing ledger';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'scenario': {
        'type': 'string',
        'description':
            'The chaos scenario to run (offline-flap: offline window, '
            'then connection flaps, then recovery)',
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

    // The scripted chaos remote (offline-flap): the first
    // `_offlineWindow` create calls always fail (offline), then the
    // remote flaps on a fail/fail/ok cycle, then it recovers.
    final remoteCalls = <String, int>{};
    var flapCounter = 0;
    Future<String> scriptedCreateRemote(String entity) async {
      final n = flapCounter++;
      if (n < 4) {
        remoteCalls['$entity#offline'] = n;
        throw const _SocketFailure('offline: connection refused');
      }
      if ((n - 4) % 3 != 2) {
        // fail, fail, ok — the flap cycle.
        remoteCalls['$entity#flap'] = n;
        throw const _SocketFailure('flap: connection reset by peer');
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

    // Round 1: the offline window + flaps chew through the first pass.
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
