import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('US1 · Computed (lazy cached derived value)', () {
    test(
      'A1: zero compute calls while source changes and derived is never read',
      () {
        final source = Signal<int>(0);
        var computeCalls = 0;
        final derived = Computed<int>([source], () {
          computeCalls++;
          return source.value * 2;
        });

        source.value = 1;
        source.value = 2;
        source.value = 3;

        expect(
          computeCalls,
          0,
          reason: 'unread derived state must cost nothing',
        );
        expect(derived.isDisposed, isFalse);
      },
    );

    test('A2: exactly one recompute on first read after a change', () {
      final source = Signal<int>(0);
      var computeCalls = 0;
      final derived = Computed<int>([source], () {
        computeCalls++;
        return source.value * 2;
      });

      expect(derived.value, 0); // first read computes once
      expect(computeCalls, 1);

      source.value = 5;
      source.value = 10; // two changes, one dirty flag

      expect(derived.value, 20);
      expect(
        computeCalls,
        2,
        reason: 'one recompute per read-after-change, not per write',
      );
    });

    test(
      'A3: repeated reads without dependency change return cache (no recompute)',
      () {
        final source = Signal<int>(2);
        var computeCalls = 0;
        final derived = Computed<int>([source], () {
          computeCalls++;
          return source.value * 10;
        });

        expect(derived.value, 20);
        expect(derived.value, 20);
        expect(derived.value, 20);
        expect(computeCalls, 1);
      },
    );

    test(
      'A4: two dependencies, one change, recompute uses current values of both',
      () {
        final a = Signal<int>(1);
        final b = Signal<int>(2);
        final sum = Computed<int>([a, b], () => a.value + b.value);

        expect(sum.value, 3);
        a.value = 10;
        expect(
          sum.value,
          12,
          reason: 'b is still read fresh at recompute time',
        );

        b.value = 5;
        expect(sum.value, 15);
      },
    );

    test('A5: reading value inside its own compute throws StateError', () {
      final source = Signal<int>(1);
      Computed<int>? derived;
      derived = Computed<int>([source], () => derived!.value + 1);
      expect(() => derived!.value, throwsStateError);
    });

    test('A6: disposed dependency read propagates StateError, no swallow', () {
      final source = Signal<int>(1);
      final derived = Computed<int>([source], () => source.value + 1);

      source.dispose();
      expect(() => derived.value, throwsStateError);
    });

    test(
      'A7: implements ReadonlySignal; listen delivers eagerly; dispose cancels dep subscriptions',
      () {
        final source = Signal<int>(1);
        final derived = Computed<num>([source], () => source.value * 2);

        final received = <num>[];
        derived.listen(received.add); // eager delivery of current value
        expect(received, [2]);

        source.value = 3; // has listeners → push mode: recomputes and notifies
        expect(received, [2, 6]);

        source.value = 4; // no actual change in derived? 4*2=8 differs → notify
        expect(received, [2, 6, 8]);

        derived.dispose();
        source.value = 100; // dep subscriptions cancelled: no further delivery
        expect(received, [2, 6, 8]);
        expect(derived.isDisposed, isTrue);
      },
    );

    test('A7b: push notification skips when computed value is unchanged', () {
      final source = Signal<int>(2);
      final derived = Computed<num>([source], () => source.value * 0);
      final received = <num>[];
      derived.listen(received.add); // 0, eager
      source.value = 99; // 99 * 0 == 0 → same derived value, no notify
      expect(received, [0]);
    });

    test('A7c: re-entering push mode rebases the delivery baseline', () {
      final source = Signal<int>(1);
      final derived = Computed<int>([source], () => source.value * 10);

      final first = <int>[];
      final firstSub = derived.listen(first.add); // eager 10
      first.clear();
      source.value = 2; // push mode → 20
      expect(first, [20]);
      firstSub.cancel(); // nobody is reading: lazy mode from here on

      source.value = 3; // lazy: marked dirty, never delivered
      final second = <int>[];
      derived.listen(second.add); // eager 30 — rebases the baseline at 30
      second.clear();

      source.value = 2; // back to 20 → must still reach the new subscriber
      expect(second, [
        20,
      ], reason: 'the stale pre-lazy baseline must not suppress this delivery');
    });
  });
}
