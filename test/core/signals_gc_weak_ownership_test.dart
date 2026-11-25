import 'package:test/test.dart';
import 'package:zuraffa/src/core/signals/zfa_signal.dart';
import 'package:zuraffa/src/core/signals/zfa_computed.dart';

/// Deterministic GC pressure for the weak-reference tests: the Dart VM has no
/// public "collect now" primitive under `dart test` (Service.getInfo().serverUri
/// is null), so allocate and discard whole chunks until the weak targets clear.
/// A strong registry such as the retired `_allSignals` list keeps its target
/// alive forever and therefore fails these assertions.
Future<void> _collectUntilCleared(List<WeakReference<dynamic>> refs) async {
  for (var pass = 0; pass < 12 && refs.any((r) => r.target != null); pass++) {
    for (var i = 0; i < 120; i++) {
      final chunk = List<int>.filled(256 * 1024, i);
      chunk[0] = i;
    }
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('ZFA-004 Signals & Weak Ownership GC Tests', () {
    test('ZfaSignal basic and computed graph evaluation', () {
      final s1 = ZfaSignal<int>(10);
      final s2 = ZfaSignal<int>(20);
      final computed = ZfaComputed<int>([s1, s2], () => s1.value + s2.value);

      expect(computed.value, 30);

      s1.value = 15;
      expect(computed.value, 35);
    });

    test(
      'diamond graph recomputes once and delivers no intermediate value',
      () {
        final a = ZfaSignal<int>(1);
        var bComputes = 0;
        var cComputes = 0;
        var dComputes = 0;
        final b = ZfaComputed<int>([a], () {
          bComputes++;
          return a.value * 2;
        });
        final c = ZfaComputed<int>([a], () {
          cComputes++;
          return a.value * 3;
        });
        final d = ZfaComputed<int>([b, c], () {
          dComputes++;
          return b.value + c.value;
        });

        final seen = <int>[];
        d.listen(seen.add); // eager delivery of 5
        expect(seen, [5]);
        seen.clear();
        bComputes = 0;
        cComputes = 0;
        dComputes = 0;

        a.value = 2; // b=4, c=6, d must see 10 exactly once

        expect(seen, [10], reason: 'no intermediate 7 may reach a listener');
        expect(bComputes, 1);
        expect(cComputes, 1);
        expect(dComputes, 1, reason: 'recomputeCount == 1 per source change');
      },
    );

    test('a computed read inside a batch sees updated dependencies', () {
      final s = ZfaSignal<int>(1);
      final doubled = ZfaComputed<int>([s], () => s.value * 2);
      expect(doubled.value, 2);

      late int observed;
      batch(() {
        s.value = 2;
        observed = doubled.value;
      });
      expect(observed, 4, reason: 'reads recompute before the batch flushes');
    });

    test('a throwing listener does not block computed invalidation', () {
      final s = ZfaSignal<int>(1);
      // Register the failing listener BEFORE the computed subscribes, so the
      // old stop-on-first-throw loop would skip it entirely.
      s.listen((v) {
        if (v == 2) throw StateError('boom');
      });
      final doubled = ZfaComputed<int>([s], () => s.value * 2);
      final seen = <int>[];
      doubled.listen(seen.add); // eager 2
      seen.clear();

      expect(() => s.value = 2, throwsStateError);
      expect(doubled.value, 4);
      expect(seen, [4], reason: 'remaining listeners still run and deliver');
    });

    test('all dispose hooks run even when one throws', () {
      final s = ZfaSignal<int>(0);
      final ran = <int>[];
      s.onDispose(() => ran.add(1));
      s.onDispose(() => throw StateError('hook boom'));
      s.onDispose(() => ran.add(3));

      expect(s.dispose, throwsStateError);
      expect(ran, [1, 3], reason: 'the failing hook cannot strand later hooks');
      expect(s.isDisposed, isTrue);
    });

    test('expando weak ownership: owner and signal are collectible', () async {
      late WeakReference<Object> ownerRef;
      late WeakReference<ZfaSignal<int>> signalRef;

      void createAndDrop() {
        final owner = Object();
        final signal = ZfaSignal<int>(42, owner: owner);
        ownerRef = WeakReference(owner);
        signalRef = WeakReference(signal);
        expect(signal.value, 42);
        // Both strong locals go out of scope when this returns.
      }

      createAndDrop();

      await _collectUntilCleared([ownerRef, signalRef]);
      expect(
        signalRef.target,
        isNull,
        reason: 'a strong global registry must not retain the signal',
      );
      expect(ownerRef.target, isNull, reason: 'the expando key must be weak');
    });

    test('disposeOwner disposes every signal owned by an object', () {
      final persistentOwner = Object();
      final persistentSignal = ZfaSignal<int>(100, owner: persistentOwner);
      expect(persistentSignal.isDisposed, isFalse);

      ZfaSignal.disposeOwner(persistentOwner);
      expect(persistentSignal.isDisposed, isTrue);
    });
  });
}
