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

    test(
      'A8: a disposed dependency during construction releases the earlier subscriptions',
      () {
        final alive = _RecordingSignal<int>(1);

        // `dead.listen` throws inside the constructor; the caller never receives
        // a Computed it could dispose, so the constructor itself must release
        // the subscription it already took. `_RecordingSignal` records the
        // cancel() calls — asserting on `alive.value` alone would pass even
        // without the cleanup (the abandoned computed has no listeners).
        expect(
          () => Computed<int>([alive, _DisposedSignal<int>()], () => 0),
          throwsStateError,
        );
        expect(
          alive.cancellations,
          [0],
          reason: 'the subscription taken before the failure is cancelled once',
        );
      },
    );
    test(
      'A9: an outer computed sees an inner computed write inside a batch',
      () {
        final source = Signal<int>(1);
        final inner = Computed<int>([source], () => source.value * 10);
        final outer = Computed<int>([inner], () => inner.value + 1);

        expect(outer.value, 11); // primes both caches

        batch(() {
          source.value = 5;
          expect(inner.value, 50, reason: 'inner recomputes on read');
          expect(
            outer.value,
            51,
            reason:
                'an invalidated inner computed must invalidate the outer '
                'cache too, even though neither dirty flag has been set',
          );
        });

        expect(outer.value, 51);
      },
    );

    test(
      'A10: an outer computed notifies once with the settled value after a batch',
      () {
        final source = Signal<int>(1);
        final inner = Computed<int>([source], () => source.value * 10);
        final outer = Computed<int>([inner], () => inner.value + 1);

        final received = <int>[];
        outer.listen(received.add); // eager 11
        received.clear();

        batch(() {
          source.value = 5;
        });

        expect(received, [
          51,
        ], reason: 'one notification, carrying the post-batch value');
      },
    );
    test(
      'A11: an outer computed revalidates an inner whose version still matches',
      () {
        final source = Signal<int>(1);
        final inner = Computed<int>([source], () => source.value * 10);
        final outer = Computed<int>([inner], () => inner.value + 1);

        expect(outer.value, 11); // primes both caches

        batch(() {
          source.value = 5;
          // Read the OUTER value first: `inner` has not recomputed yet, so
          // its version still matches the one `outer` captured. A9 covers
          // the version-mismatch branch; this covers the recursive
          // freshness validation that has to look through `inner` to the
          // source.
          expect(
            outer.value,
            51,
            reason: 'a still-fresh inner must be validated recursively',
          );
        });

        expect(inner.value, 50);
        expect(outer.value, 51);
      },
    );

    test(
      'A12: a shared dependency is validated once per pass, not once per path',
      () {
        // Layered diamond: each layer reads the SAME two computed nodes of
        // the layer below it. Freshness validation walks one route per
        // root-to-leaf path, so a graph of O(depth) nodes costs O(2^depth)
        // checks on every clean read.
        const depth = 18;
        final base = Signal<int>(0);
        ReadonlySignal<int> layer = base;
        for (var i = 0; i < depth; i++) {
          final below = layer;
          final left = Computed<int>([below], () => below.value + 1);
          final right = Computed<int>([below], () => below.value + 2);
          layer = Computed<int>([left, right], () => left.value + right.value);
        }
        final outer = layer;

        final before = outer.value; // primes every cache

        Computed.resetFreshnessCheckCount();
        batch(() {
          base.value = 1; // no dirty flag yet: the pass must discover this
          expect(
            outer.value,
            isNot(before),
            reason: 'the invalidation must reach the outer cache',
          );
        });

        // One memoised validation pass is linear in the node count, but the
        // recompute cascade that follows it drives one pass per recomputed
        // node — measured 11.1 * depth^2 checks on this graph (3605 at
        // depth 18, 6602 at depth 24). The bound states that polynomial shape:
        // a regression to the O(2^depth) walk this memo removes is 262144 at
        // depth 18, far above it.
        expect(
          Computed.freshnessCheckCount,
          lessThan(depth * depth * 20),
          reason: 'a shared dependency is checked once per validation pass',
        );
      },
    );

    test(
      'A13: the memo key carries the captured version, not just the dependency',
      () {
        // `p` re-validates the shared node and captures its NEW version; `q`
        // keeps the OLDER one. Both parents are otherwise clean, so `p`'s
        // answer ("the shared node is unchanged") is false and `q`'s is true:
        // a key that dropped the captured version would answer `q` from `p`'s
        // entry, and `outer` would keep a cache built before `shared` changed.
        final base = Signal<int>(0);
        final shared = Computed<int>([base], () => base.value * 10);
        final p = Computed<int>([shared], () => shared.value + 1);
        final q = Computed<int>([shared], () => shared.value + 2);
        // `outer` reads only `p`, so `q` keeps whatever version of `shared`
        // it captured when it was last read.
        var outerComputes = 0;
        final outer = Computed<int>([p, q], () {
          outerComputes++;
          return p.value + 1;
        });

        q.value; // primes shared, then q
        outer.value; // primes p and captures [p, q]

        // One batch throughout: a batch flush marks every notified computed
        // dirty, which would short-circuit the freshness walk being measured.
        late int computesDuringPass;
        batch(() {
          base.value = 1;
          p.value; // p re-captures the new shared version
          outer.value; // re-primes: captures p's version, q's older one
          final before = outerComputes;
          outer.value; // the measured pass: p is fresh, q is not
          computesDuringPass = outerComputes - before;
        });

        expect(
          computesDuringPass,
          1,
          reason: 'each captured version is a distinct freshness question',
        );
        expect(q.value, 12, reason: 'the stale parent still recomputes');
      },
    );

    test('A14: the memo is per pass — a second read validates again', () {
      final base = Signal<int>(0);
      final inner = Computed<int>([base], () => base.value * 10);
      final outer = Computed<int>([inner], () => inner.value + 1);
      expect(outer.value, 1); // primes both caches

      Computed.resetFreshnessCheckCount();
      outer.value;
      final firstRead = Computed.freshnessCheckCount;
      outer.value;
      final secondRead = Computed.freshnessCheckCount - firstRead;

      expect(
        firstRead,
        greaterThan(0),
        reason: 'a read validates its dependency chain',
      );
      expect(
        secondRead,
        firstRead,
        reason: 'the memo is scoped to one pass, never cached across reads',
      );
    });
    test(
      'A15: the memo key compares dependencies by identity, not equality',
      () {
        // Two DISTINCT computed nodes that compare equal. A key built from a
        // Dart record compares its fields with `==`, so the two would share one
        // memo entry: `clean` stores "unchanged" and `stale` reuses it, so the
        // outer cache keeps a value built before `b` changed.
        final a = Signal<int>(1);
        final b = Signal<int>(1);
        final clean = _AlwaysEqualComputed<int>([a], () => a.value);
        final stale = _AlwaysEqualComputed<int>([b], () => b.value);
        final outer = Computed<int>([
          clean,
          stale,
        ], () => clean.value + stale.value);
        expect(outer.value, 2); // primes all three at the same captured version

        batch(() {
          b.value = 5; // invalidates `stale` alone
          expect(
            outer.value,
            6,
            reason: 'a distinct-but-equal dependency is validated on its own',
          );
        });

        expect(stale.value, 5);
      },
    );
  });
}

/// A [Computed] that compares equal to every other instance — the value-equality
/// hazard a memo key must not inherit.
class _AlwaysEqualComputed<T> extends Computed<T> {
  _AlwaysEqualComputed(super.dependencies, super.compute);

  @override
  bool operator ==(Object other) => other is _AlwaysEqualComputed<T>;

  @override
  int get hashCode => 0;
}

/// Test double that records every subscription cancellation, so a test can
/// assert that a subscription was actually released (and how many times).
class _RecordingSignal<T> implements ReadonlySignal<T> {
  _RecordingSignal(this._value);

  final T _value;
  final List<int> cancellations = [];
  int _nextId = 0;

  @override
  T get value => _value;

  @override
  SignalSubscription listen(void Function(T value) callback) {
    final id = _nextId++;
    return SignalSubscription(() => cancellations.add(id));
  }

  @override
  Signal<R> map<R>(R Function(T value) transform, {bool autoDispose = true}) =>
      throw UnimplementedError('not used by this test');
}

/// A dependency that is already disposed: `listen` throws, as `Signal.listen`
/// does after disposal.
class _DisposedSignal<T> implements ReadonlySignal<T> {
  @override
  T get value => throw StateError('Signal has been disposed.');

  @override
  SignalSubscription listen(void Function(T value) callback) =>
      throw StateError('Signal has been disposed.');

  @override
  Signal<R> map<R>(R Function(T value) transform, {bool autoDispose = true}) =>
      throw UnimplementedError('not used by this test');
}
