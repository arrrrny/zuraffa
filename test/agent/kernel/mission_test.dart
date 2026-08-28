import 'package:test/test.dart';
import 'package:zuraffa/src/agent/kernel/agent_kernel.dart';

void main() {
  group('MissionKey', () {
    test('coalesces identical four-tuples', () {
      final a = MissionKey(
        sparkType: 'product_scan',
        normalizedValue: 'sku-123',
        country: 'US',
        strategyVariant: 'default',
      );
      final b = MissionKey(
        sparkType: 'product_scan',
        normalizedValue: 'sku-123',
        country: 'US',
        strategyVariant: 'default',
      );
      expect(a, equals(b));
      expect(a.canonical, equals(b.canonical));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different strategy variant does NOT coalesce', () {
      final a = MissionKey(
        sparkType: 'product_scan',
        normalizedValue: 'sku-123',
        country: 'US',
        strategyVariant: 'default',
      );
      final b = MissionKey(
        sparkType: 'product_scan',
        normalizedValue: 'sku-123',
        country: 'US',
        strategyVariant: 'aggressive',
      );
      expect(a, isNot(equals(b)));
    });

    test('different country does NOT coalesce', () {
      final a = MissionKey(
        sparkType: 'product_scan',
        normalizedValue: 'sku-123',
        country: 'US',
        strategyVariant: 'default',
      );
      final b = MissionKey(
        sparkType: 'product_scan',
        normalizedValue: 'sku-123',
        country: 'DE',
        strategyVariant: 'default',
      );
      expect(a, isNot(equals(b)));
    });

    test('canonical string is deterministic and stable', () {
      final k = MissionKey(
        sparkType: 'price_check',
        normalizedValue: 'banana',
        country: 'CA',
        strategyVariant: 'aggressive',
      );
      expect(k.canonical, equals('price_check|banana|CA|aggressive'));
    });
  });

  group('Mission', () {
    test('starts in pending status with no outcome', () {
      final m = Mission(
        id: 'm1',
        key: MissionKey(
          sparkType: 's',
          normalizedValue: 'v',
          country: 'US',
          strategyVariant: 'default',
        ),
        callerId: 'c1',
      );
      expect(m.status, equals(MissionStatus.pending));
      expect(m.outcome, isNull);
      expect(m.isActive, isTrue);
      expect(m.partials, isEmpty);
    });
  });

  group('MissionOutcome', () {
    test('labels match spec', () {
      expect(const OutcomeCompleted(null).label, equals('completed'));
      expect(const OutcomeCancelledPartial([]).label, equals('cancelled_partial'));
      expect(OutcomeFailed('boom').label, equals('failed'));
      expect(
        OutcomeCachedServed(const OutcomeCompleted(null)).label,
        equals('cached_served'),
      );
    });
  });
}
