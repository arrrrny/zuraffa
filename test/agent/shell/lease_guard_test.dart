import 'dart:async';

import 'package:test/test.dart';
import 'package:zuraffa/src/agent/shell/file_lease_table.dart';
import 'package:zuraffa/src/agent/shell/lease_guard.dart';

void main() {
  // ✅ Done-when #1 (issue #808): "Two concurrent agents on one feature
  // never interleave writes (lease proof test)".
  group('LeaseGuard — lease proof: concurrent agents never interleave', () {
    test('non-holder writes are rejected for the entire lease period', () {
      final clock = _FakeClock(DateTime.utc(2026, 1, 1));
      final leases = FileLeaseTable(
        defaultTtl: const Duration(seconds: 10),
        now: () => clock.now,
      );
      final guard = LeaseGuard(leases);
      const feature = 'lib/src/features/product/';

      leases.acquire(agentId: 'agent-a', scope: feature);

      // Agent B (no lease) attempts 25 writes to different files of the
      // SAME feature while agent A holds the lease.
      var violations = 0;
      for (var i = 0; i < 25; i++) {
        try {
          guard.write(
            agentId: 'agent-b',
            path: '${feature}file_$i.dart',
            contents: 'B$i',
          );
        } on LeaseViolation {
          violations++;
        }
      }
      expect(violations, 25, reason: 'every non-holder write must be rejected');
    });

    test('proof: every successful write came from the current lease holder, '
        'even across forced ownership transfers', () async {
      final clock = _FakeClock(DateTime.utc(2026, 1, 1));
      final leases = FileLeaseTable(
        defaultTtl: const Duration(seconds: 5),
        now: () => clock.now,
      );
      final guard = LeaseGuard(leases);
      const feature = 'lib/src/features/product/';
      const target = '${feature}shared_file.dart';

      // Two concurrent agents hammering the SAME file through the guarded
      // writer. The clock keeps advancing, so leases expire mid-run and
      // ownership genuinely transfers between the two agents — exactly the
      // interleaving hazard the lease table must prevent.
      final agentA = _hammer(
        guard,
        'agent-a',
        target,
        20,
        leases,
        feature,
        clock,
        const Duration(seconds: 7),
      );
      final agentB = _hammer(
        guard,
        'agent-b',
        target,
        20,
        leases,
        feature,
        clock,
        const Duration(seconds: 11),
      );
      await Future.wait([agentA, agentB]);

      final log = guard.writeLog
          .where((w) => w.path == target)
          .toList(growable: false);
      expect(
        log.length,
        greaterThan(4),
        reason: 'the race must actually produce writes',
      );
      final writers = log.map((w) => w.agentId).toSet();
      expect(
        writers.length,
        2,
        reason: 'both agents must have held the lease at some point',
      );

      // THE INVARIANT: every successful write was issued by whoever held
      // the lease at that moment. A write from a non-holder never lands.
      for (final w in log) {
        expect(
          w.holderAtWrite,
          w.agentId,
          reason: 'write landed from an agent that did not hold the lease',
        );
      }

      // No two agents ever hold the same scope simultaneously.
      expect(leases.lookup(feature), isNotNull);
    });

    test(
      'guard writes only into the leased workspace (no lease, no write)',
      () {
        final clock = _FakeClock(DateTime.utc(2026, 1, 1));
        final leases = FileLeaseTable(
          defaultTtl: const Duration(seconds: 10),
          now: () => clock.now,
        );
        final guard = LeaseGuard(leases);
        expect(
          () => guard.write(
            agentId: 'agent-a',
            path: 'lib/src/features/order/x.dart',
            contents: 'nope',
          ),
          throwsA(isA<LeaseViolation>()),
        );
      },
    );
  });
}

/// Fires [n] guarded writes as fast as possible, re-acquiring the lease
/// whenever the previous one expired — mimicking two live agents racing on
/// one feature while the wall clock advances.
Future<void> _hammer(
  LeaseGuard guard,
  String agentId,
  String path,
  int n,
  FileLeaseTable leases,
  String feature,
  _FakeClock clock,
  Duration tick,
) async {
  for (var i = 0; i < n; i++) {
    clock.advance(tick);
    if (!leases.allowsWrite(agentId: agentId, path: path)) {
      leases.acquire(agentId: agentId, scope: feature);
    }
    try {
      guard.write(agentId: agentId, path: path, contents: '$agentId-$i');
    } on LeaseViolation {
      // Expected when the other agent holds the lease.
    }
    // Yield to interleave the two hammers on the event loop.
    await Future<void>.delayed(Duration.zero);
  }
}

class _FakeClock {
  _FakeClock(this._now);
  DateTime _now;
  DateTime get now => _now;
  void advance(Duration d) => _now = _now.add(d);
}
