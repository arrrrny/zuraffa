import 'package:test/test.dart';
import 'package:zuraffa/src/models/generator_config.dart';

/// Bug 1966 — `GeneratorConfig.toJson → fromJson` round-trip silently drops
/// every sync/strategy setting.
///
/// `toJson` emits 8 dedicated sync/strategy keys — `sync`, `strategy`,
/// `strategy_names`, `sync_direction`, `sync_batch_size`, `sync_max_retries`,
/// `sync_backoff_base_ms`, `sync_backoff_max_ms` — but `fromJson` never reads
/// any of them, so a config saved and replayed resets `enableSync`,
/// `enableStrategy`, `strategyNames` and all five sync tunables back to the
/// constructor defaults with no error and no warning.
///
/// Fix: `fromJson` reads the same 8 dedicated keys back (mirroring `toJson`),
/// following the pattern established by #1965 / #1962: dedicated keys on both
/// sides, `== true` for bool reads.
void main() {
  group('bug 1966 — GeneratorConfig sync/strategy JSON round-trip', () {
    test('sync settings survive the round-trip', () {
      final config = GeneratorConfig(
        name: 'Deal',
        outputDir: 'lib/src',
        methods: ['get'],
        enableSync: true,
        syncDirection: 'bidirectional',
        syncBatchSize: 120,
        syncMaxRetries: 9,
        syncBackoffBaseMs: 250,
        syncBackoffMaxMs: 30000,
      );

      final restored = GeneratorConfig.fromJson(config.toJson(), config.name);

      expect(
        restored.enableSync,
        isTrue,
        reason: 'toJson emits "sync" but fromJson must read it back',
      );
      expect(
        restored.syncDirection,
        'bidirectional',
        reason: 'toJson emits "sync_direction" but fromJson must read it back',
      );
      expect(
        restored.syncBatchSize,
        120,
        reason: 'toJson emits "sync_batch_size" but fromJson must read it back',
      );
      expect(
        restored.syncMaxRetries,
        9,
        reason:
            'toJson emits "sync_max_retries" but fromJson must read it back',
      );
      expect(
        restored.syncBackoffBaseMs,
        250,
        reason:
            'toJson emits "sync_backoff_base_ms" but fromJson must read it back',
      );
      expect(
        restored.syncBackoffMaxMs,
        30000,
        reason:
            'toJson emits "sync_backoff_max_ms" but fromJson must read it back',
      );
    });

    test('strategy settings survive the round-trip', () {
      final config = GeneratorConfig(
        name: 'Deal',
        outputDir: 'lib/src',
        methods: ['get'],
        enableStrategy: true,
        strategyNames: ['offlineFirst', 'optimistic'],
      );

      final restored = GeneratorConfig.fromJson(config.toJson(), config.name);

      expect(
        restored.enableStrategy,
        isTrue,
        reason: 'toJson emits "strategy" but fromJson must read it back',
      );
      expect(
        restored.strategyNames,
        ['offlineFirst', 'optimistic'],
        reason: 'toJson emits "strategy_names" but fromJson must read it back',
      );
    });

    test('defaults stay intact when the keys are absent', () {
      final config = GeneratorConfig(
        name: 'Deal',
        outputDir: 'lib/src',
        methods: ['get'],
      );

      final restored = GeneratorConfig.fromJson(config.toJson(), config.name);

      expect(restored.enableSync, isFalse);
      expect(restored.enableStrategy, isFalse);
      expect(restored.strategyNames, isEmpty);
      expect(restored.syncDirection, 'push');
      expect(restored.syncBatchSize, 50);
      expect(restored.syncMaxRetries, 5);
      expect(restored.syncBackoffBaseMs, 1000);
      expect(restored.syncBackoffMaxMs, 60000);
    });
  });
}
