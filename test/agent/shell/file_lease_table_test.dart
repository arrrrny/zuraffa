import 'package:test/test.dart';
import 'package:zuraffa/src/agent/shell/file_lease_table.dart';

void main() {
  group('FileLeaseTable — real-time, crash-safe file ownership (#808)', () {
    late FileLeaseTable leases;

    setUp(() {
      leases = FileLeaseTable(defaultTtl: const Duration(minutes: 5));
    });

    test('grants a lease to the first agent', () {
      final grant = leases.acquire(
        agentId: 'agent-a',
        scope: 'lib/src/features/product/',
      );
      expect(grant.granted, isTrue);
      expect(grant.lease, isNotNull);
      expect(grant.lease!.holderId, 'agent-a');
      expect(grant.lease!.scope, 'lib/src/features/product/');
    });

    test('denies a second agent while the first holds the lease', () {
      leases.acquire(agentId: 'agent-a', scope: 'lib/src/features/product/');
      final grant = leases.acquire(
        agentId: 'agent-b',
        scope: 'lib/src/features/product/',
      );
      expect(grant.granted, isFalse);
      expect(grant.conflict, isNotNull);
      expect(grant.conflict!.holderId, 'agent-a');
    });

    test('release frees the scope for another agent', () {
      leases.acquire(agentId: 'agent-a', scope: 'lib/src/features/product/');
      leases.release(agentId: 'agent-a', scope: 'lib/src/features/product/');
      final grant = leases.acquire(
        agentId: 'agent-b',
        scope: 'lib/src/features/product/',
      );
      expect(grant.granted, isTrue);
    });

    test('only the holder can release its own lease', () {
      leases.acquire(agentId: 'agent-a', scope: 'lib/src/features/product/');
      expect(
        () => leases.release(
          agentId: 'agent-b',
          scope: 'lib/src/features/product/',
        ),
        throwsA(isA<LeaseNotHeld>()),
      );
    });

    test('scope lease covers every nested path (prefix semantics)', () {
      leases.acquire(agentId: 'agent-a', scope: 'lib/src/features/product/');
      expect(
        leases.allowsWrite(
          agentId: 'agent-a',
          path: 'lib/src/features/product/domain/usecase/foo.dart',
        ),
        isTrue,
      );
      expect(
        leases.allowsWrite(
          agentId: 'agent-a',
          path: 'lib/src/features/order/domain/usecase/bar.dart',
        ),
        isFalse,
      );
    });

    test('renew extends the expiry of a held lease', () {
      final clock = _FakeClock(DateTime.utc(2026, 1, 1));
      final table = FileLeaseTable(
        defaultTtl: const Duration(seconds: 10),
        now: () => clock.now,
      );
      table.acquire(agentId: 'agent-a', scope: 'lib/src/features/product/');
      clock.advance(const Duration(seconds: 8));
      table.renew(agentId: 'agent-a', scope: 'lib/src/features/product/');
      clock.advance(const Duration(seconds: 8));
      // 16s elapsed but only 8s since the renew → still held.
      expect(
        table.allowsWrite(
          agentId: 'agent-a',
          path: 'lib/src/features/product/x.dart',
        ),
        isTrue,
      );
    });

    test('steal-on-timeout: expired lease is reclaimable by another agent', () {
      final clock = _FakeClock(DateTime.utc(2026, 1, 1));
      final table = FileLeaseTable(
        defaultTtl: const Duration(seconds: 10),
        now: () => clock.now,
      );
      table.acquire(agentId: 'agent-a', scope: 'lib/src/features/product/');
      clock.advance(const Duration(seconds: 11));

      final grant = table.acquire(
        agentId: 'agent-b',
        scope: 'lib/src/features/product/',
      );
      expect(grant.granted, isTrue, reason: 'expired lease must be stealable');
      expect(grant.stoleFrom, 'agent-a');

      // The stale holder lost ownership: its writes are no longer allowed.
      expect(
        table.allowsWrite(
          agentId: 'agent-a',
          path: 'lib/src/features/product/x.dart',
        ),
        isFalse,
      );
    });

    test(
      'crash-safe: a dead agent needs NO release — TTL expiry alone frees',
      () {
        final clock = _FakeClock(DateTime.utc(2026, 1, 1));
        final table = FileLeaseTable(
          defaultTtl: const Duration(seconds: 10),
          now: () => clock.now,
        );
        table.acquire(agentId: 'agent-a', scope: 'lib/src/features/product/');
        // Agent A is kill -9'd: no release call ever arrives.
        clock.advance(const Duration(seconds: 30));
        table.sweepExpired();
        final grant = table.acquire(
          agentId: 'agent-b',
          scope: 'lib/src/features/product/',
        );
        expect(grant.granted, isTrue);
      },
    );

    test('sweepExpired reports the stolen scopes', () {
      final clock = _FakeClock(DateTime.utc(2026, 1, 1));
      final table = FileLeaseTable(
        defaultTtl: const Duration(seconds: 10),
        now: () => clock.now,
      );
      table.acquire(agentId: 'agent-a', scope: 'lib/src/features/product/');
      table.acquire(agentId: 'agent-b', scope: 'lib/src/features/order/');
      clock.advance(const Duration(seconds: 11));
      final swept = table.sweepExpired();
      expect(
        swept.map((l) => l.scope).toSet(),
        containsAll(<String>[
          'lib/src/features/product/',
          'lib/src/features/order/',
        ]),
      );
    });
  });
}

class _FakeClock {
  _FakeClock(this._now);
  DateTime _now;
  DateTime get now => _now;
  void advance(Duration d) => _now = _now.add(d);
}
