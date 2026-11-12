import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('US2 · batch (synchronous notification deferral)', () {
    test('B1: three writes produce exactly one notification per listener', () {
      final a = Signal<int>(0);
      final b = Signal<int>(0);
      var notifications = 0;
      (int, int)? lastSeen;

      Signal.combine(a, b, (x, y) => (x, y)).listen((pair) {
        notifications++;
        lastSeen = pair;
      }); // eager delivery: notifications starts at 1
      notifications = 0;

      final result = batch(() {
        a.value = 1;
        b.value = 2;
        return 'done';
      });

      expect(result, 'done');
      expect(notifications, 1, reason: 'one cascade per batch, not three');
      expect(lastSeen, (1, 2));
    });

    test('B2: reads inside the boundary see freshly written values', () {
      final a = Signal<int>(0);
      final observed = <int>[];

      batch(() {
        a.value = 7;
        observed.add(a.value); // reads are NEVER deferred
      });

      expect(observed, [7]);
    });

    test(
      'B3: throwing callback still flushes deferred notifications (finally, no rollback)',
      () {
        final a = Signal<int>(0);
        var notifications = 0;
        a.listen((_) => notifications++);
        notifications = 0; // eager delivery

        expect(() {
          batch(() {
            a.value = 5;
            throw StateError('boom');
          });
        }, throwsStateError);

        expect(a.value, 5, reason: 'no rollback');
        expect(notifications, 1, reason: 'flush happens in finally');
      },
    );

    test('B4: nested batches defer until the outermost boundary exits', () {
      final a = Signal<int>(0);
      final b = Signal<int>(0);
      var notifications = 0;
      Signal.combine(a, b, (x, y) => x + y).listen((_) => notifications++);
      notifications = 0;

      batch(() {
        a.value = 1;
        batch(() {
          a.value = 2;
          b.value = 3;
        });
        // inner batch exit must NOT flush
        expect(notifications, 0, reason: 'inner boundary defers to outermost');
      });

      expect(notifications, 1);
    });

    test(
      'B5: same signal written twice notifies once with the final value',
      () {
        final a = Signal<int>(0);
        final seen = <int>[];
        a.listen(seen.add); // eager: [0]
        seen.clear();

        batch(() {
          a.value = 10;
          a.value = 20;
          a.value = 30;
        });

        expect(seen, [30], reason: 'per-signal coalescing to the final value');
      },
    );

    test(
      'B6: writes outside any batch notify immediately (baseline unchanged)',
      () {
        final a = Signal<int>(0);
        final seen = <int>[];
        a.listen(seen.add); // eager delivery: [0]
        seen.clear();

        a.value = 1;
        expect(seen, [1], reason: 'no batch, no deferral');
        a.value = 2;
        expect(seen, [1, 2]);
      },
    );
  });
}
