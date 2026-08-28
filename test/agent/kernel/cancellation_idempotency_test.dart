import 'package:test/test.dart';
import 'package:zuraffa/src/agent/kernel/agent_kernel.dart';

void main() {
  group('IdempotencyCache (FR-007)', () {
    test('lookup returns null when disabled', () {
      final cache = IdempotencyCache(enabled: false);
      final key = MissionKey(
        sparkType: 's',
        normalizedValue: 'v',
        country: 'US',
        strategyVariant: 'default',
      );
      cache.store(key, const OutcomeCompleted(null));
      expect(cache.lookup(key), isNull);
    });

    test('lookup returns null when TTL is zero', () {
      final cache = IdempotencyCache(ttl: Duration.zero);
      final key = MissionKey(
        sparkType: 's',
        normalizedValue: 'v',
        country: 'US',
        strategyVariant: 'default',
      );
      cache.store(key, const OutcomeCompleted(null));
      expect(cache.lookup(key), isNull);
    });

    test('store then lookup wraps in OutcomeCachedServed', () {
      final cache = IdempotencyCache(
        ttl: const Duration(minutes: 5),
        enabled: true,
      );
      final key = MissionKey(
        sparkType: 's',
        normalizedValue: 'v',
        country: 'US',
        strategyVariant: 'default',
      );
      cache.store(key, const OutcomeCompleted('payload'));
      final got = cache.lookup(key);
      expect(got, isA<OutcomeCachedServed>());
      final cached = got as OutcomeCachedServed;
      expect(cached.cached, isA<OutcomeCompleted>());
      expect((cached.cached as OutcomeCompleted).result, equals('payload'));
    });

    test('expired entry is evicted on lookup', () async {
      final cache = IdempotencyCache(
        ttl: const Duration(milliseconds: 30),
        enabled: true,
      );
      final key = MissionKey(
        sparkType: 's',
        normalizedValue: 'v',
        country: 'US',
        strategyVariant: 'default',
      );
      cache.store(key, const OutcomeCompleted(null));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cache.lookup(key), isNull);
      expect(cache.size, equals(0));
    });

    test('LRU eviction at maxEntries', () {
      final cache = IdempotencyCache(
        ttl: const Duration(minutes: 5),
        maxEntries: 2,
      );
      final k1 = MissionKey(
        sparkType: 's',
        normalizedValue: '1',
        country: 'US',
        strategyVariant: 'd',
      );
      final k2 = MissionKey(
        sparkType: 's',
        normalizedValue: '2',
        country: 'US',
        strategyVariant: 'd',
      );
      final k3 = MissionKey(
        sparkType: 's',
        normalizedValue: '3',
        country: 'US',
        strategyVariant: 'd',
      );
      cache.store(k1, const OutcomeCompleted(null));
      cache.store(k2, const OutcomeCompleted(null));
      // Lookup k1 to refresh its position
      cache.lookup(k1);
      // Store k3 — should evict k2 (least recently used).
      cache.store(k3, const OutcomeCompleted(null));

      expect(cache.lookup(k1), isNotNull,
          reason: 'k1 was accessed recently, should survive');
      expect(cache.lookup(k2), isNull,
          reason: 'k2 was LRU, should be evicted');
      expect(cache.lookup(k3), isNotNull);
    });
  });

  group('PartialSalvager (FR-005)', () {
    test('salvages accumulated partials as cancelled_partial', () {
      final salvager = PartialSalvager();
      final mission = Mission(
        id: 'm1',
        key: MissionKey(
          sparkType: 's',
          normalizedValue: 'v',
          country: 'US',
          strategyVariant: 'd',
        ),
        callerId: 'c1',
      );
      mission.partials.addAll(['p1', 'p2']);

      final outcome = salvager.salvage(mission);
      expect(outcome.label, equals('cancelled_partial'));
      expect(outcome.partials, equals(['p1', 'p2']));
      expect(mission.status, equals(MissionStatus.cancelled));
      expect(mission.outcome, same(outcome));
    });

    test('empty salvage still records cancelled_partial (edge case)', () {
      final salvager = PartialSalvager();
      final mission = Mission(
        id: 'm1',
        key: MissionKey(
          sparkType: 's',
          normalizedValue: 'v',
          country: 'US',
          strategyVariant: 'd',
        ),
        callerId: 'c1',
      );
      final outcome = salvager.salvage(mission);
      expect(outcome.label, equals('cancelled_partial'));
      expect(outcome.partials, isEmpty);
    });
  });

  group('Cancellation (FR-004, FR-006)', () {
    test('CancelToken disposes all handles within grace period', () async {
      final token = CancelToken(gracePeriod: const Duration(milliseconds: 100));
      final h1 = FakeResourceHandle('h1');
      final h2 = FakeResourceHandle('h2');

      final result = await runCancellation(token, [h1, h2]);

      expect(h1.wasDisposed, isTrue);
      expect(h2.wasDisposed, isTrue);
      expect(result.disposedHandles, containsAll(['h1', 'h2']));
      expect(result.leakedHandles, isEmpty);
      expect(result.zeroLeak, isTrue);
    });

    test('leaking handle is reported (FR-006 leak assertion)', () async {
      final token = CancelToken(gracePeriod: const Duration(milliseconds: 50));
      final ok = FakeResourceHandle('ok');
      final leak = LeakingResourceHandle('leak');

      final result = await runCancellation(token, [ok, leak]);

      expect(ok.wasDisposed, isTrue);
      expect(result.leakedHandles, contains('leak'));
      expect(result.zeroLeak, isFalse);
    });
  });
}
