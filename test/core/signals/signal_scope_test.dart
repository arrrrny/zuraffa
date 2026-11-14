import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('US4 · SignalScope (auto-ownership)', () {
    test('D1: dispose disposes every signal created inside run', () {
      final scope = SignalScope();
      late Signal<int> a;
      late Signal<int> b;

      scope.run(() {
        a = Signal<int>(1);
        b = Signal<int>(2);
      });

      expect(a.isDisposed, isFalse);
      expect(b.isDisposed, isFalse);

      scope.dispose();

      expect(
        a.isDisposed,
        isTrue,
        reason: 'scope owns everything created inside run',
      );
      expect(b.isDisposed, isTrue);
    });

    test('D2: nested scope is disposed with its parent', () {
      final outer = SignalScope();
      SignalScope inner = SignalScope(); // placeholder, re-created inside
      late Signal<int> ownedByInner;

      outer.run(() {
        inner = SignalScope(); // constructed while outer is active → child
        inner.run(() {
          ownedByInner = Signal<int>(10);
        });
      });

      expect(inner.isDisposed, isFalse);
      outer.dispose();
      expect(
        inner.isDisposed,
        isTrue,
        reason: 'nesting: parent disposal cascades to child scopes',
      );
      expect(ownedByInner.isDisposed, isTrue);
    });

    test('D3: signals created outside any run boundary are not captured', () {
      final scope = SignalScope();
      final outside = Signal<int>(5);

      scope.run(() {
        final inside = Signal<int>(6);
        expect(inside.isDisposed, isFalse);
      });

      scope.dispose();
      expect(
        outside.isDisposed,
        isFalse,
        reason: 'no global capture of outside signals',
      );
    });

    test('D4: disposal releases owned signals listeners', () {
      final scope = SignalScope();
      late Signal<int> s;
      var received = 0;

      scope.run(() {
        s = Signal<int>(0);
        s.listen((_) => received++); // eager: 1
      });
      expect(received, 1);

      scope.dispose();
      final threw = <String>[];
      try {
        s.value = 99;
      } on StateError {
        threw.add('blocked');
      }
      expect(threw, ['blocked'], reason: 'disposed signal rejects writes');
      expect(received, 1, reason: 'listeners were released at disposal');
    });

    test('D5: dispose is idempotent', () {
      final scope = SignalScope();
      late Signal<int> s;
      scope.run(() {
        s = Signal<int>(1);
      });

      scope.dispose();
      scope.dispose(); // must not throw
      expect(s.isDisposed, isTrue);
    });

    test('D6: run restores the previous active scope (finally)', () {
      final outer = SignalScope();
      final inner = SignalScope();
      late Signal<int> innerOwned;

      outer.run(() {
        inner.run(() {
          innerOwned = Signal<int>(1);
        });
        // back in outer's boundary after inner's run exits
        final outerOwned = Signal<int>(2);
        expect(outerOwned.isDisposed, isFalse);
      });

      inner.dispose();
      expect(innerOwned.isDisposed, isTrue);
      outer.dispose();
    });

    test('D7: run on a disposed scope throws and runs nothing', () {
      final scope = SignalScope();
      scope.dispose();
      var ran = false;

      expect(
        () => scope.run(() => ran = true),
        throwsStateError,
        reason: 'a disposed scope can never release what it owns',
      );
      expect(ran, isFalse, reason: 'the callback must not run');
    });

    test(
      'D8: a signal constructed after its scope was disposed is disposed at once',
      () {
        final scope = SignalScope();
        late Signal<int> orphan;

        scope.run(() {
          scope.dispose(); // the boundary outlives its own disposal
          orphan = Signal<int>(1);
        });

        expect(
          orphan.isDisposed,
          isTrue,
          reason:
              'nobody can release a signal the disposed scope never '
              'adopted, so it is released at construction',
        );
      },
    );

    test('D9: a map derived disposed during construction never subscribes', () {
      final source = Signal<int>(0);
      final scope = SignalScope();
      Signal<int>? mapped;

      scope.run(() {
        source.listen((_) {
          scope.dispose(); // the scope that owns what map() builds
          mapped = source.map((v) => v * 2);
        });
        source.value = 1; // inside the boundary: map() is scope-owned
      });

      expect(mapped, isNotNull);
      expect(
        mapped!.isDisposed,
        isTrue,
        reason: 'the disposed scope releases the derived signal at once',
      );
      // The live source must not keep a listener writing to the dead
      // derived signal: every later source write would throw, and the
      // caller holds no subscription it could cancel.
      expect(() => source.value = 2, returnsNormally);
      expect(() => source.value = 3, returnsNormally);
    });

    test(
      'D10: a combined signal disposed during construction never subscribes',
      () {
        final a = Signal<int>(0);
        final b = Signal<int>(1);
        final scope = SignalScope();
        Signal<int>? combined;

        scope.run(() {
          a.listen((_) {
            scope.dispose();
            combined = Signal.combine(a, b, (x, y) => x + y);
          });
          a.value = 1; // inside the boundary: combine() is scope-owned
        });

        expect(combined, isNotNull);
        expect(combined!.isDisposed, isTrue);
        expect(() => a.value = 2, returnsNormally);
        expect(() => b.value = 2, returnsNormally);
      },
    );

    test(
      'D11: a map derived disposed during its eager subscribe is cleaned up',
      () {
        final source = Signal<int>(0);
        final scope = SignalScope();
        Signal<int>? mapped;
        var transformCalls = 0;

        scope.run(() {
          mapped = source.map((v) {
            transformCalls++;
            // The construction-time read above is call 1; every later call is
            // an eager delivery, and the transform is the user's code.
            if (transformCalls > 1) scope.dispose();
            return v * 2;
          });
        });

        expect(mapped, isNotNull);
        expect(
          mapped!.isDisposed,
          isTrue,
          reason: 'the transform disposed the scope that owns the derived',
        );
        final callsAfterSetup = transformCalls;
        // `listen` registers before its eager delivery and cleans up nothing
        // on throw: without a cancel here the source keeps a listener that
        // throws on every later write, and nobody holds the subscription.
        expect(() => source.value = 1, returnsNormally);
        expect(() => source.value = 2, returnsNormally);
        expect(
          transformCalls,
          callsAfterSetup,
          reason: 'the cancelled listener is never delivered again',
        );
      },
    );

    test(
      'D12: a combined signal disposed during its eager subscribe is cleaned up',
      () {
        final a = Signal<int>(0);
        final b = Signal<int>(1);
        final scope = SignalScope();
        Signal<int>? combined;
        var combinerCalls = 0;

        scope.run(() {
          combined = Signal.combine(a, b, (x, y) {
            combinerCalls++;
            if (combinerCalls > 1) scope.dispose();
            return x + y;
          });
        });

        expect(combined, isNotNull);
        expect(combined!.isDisposed, isTrue);
        final callsAfterSetup = combinerCalls;
        expect(() => a.value = 2, returnsNormally);
        expect(() => b.value = 2, returnsNormally);
        expect(() => a.value = 3, returnsNormally);
        expect(
          combinerCalls,
          callsAfterSetup,
          reason: 'both cancelled listeners are never delivered again',
        );
      },
    );

    test(
      'D13: a disposal that throws during the eager subscribe leaves no leaked listener',
      () {
        // Same shape as D11, but the transform disposes the owning scope and
        // then touches a signal the scope owned: the eager delivery THROWS.
        // `listen` registers the listener before its eager delivery, so the
        // throw must not leave that registration on the source — the caller
        // never receives the subscription it would need to cancel.
        final source = Signal<int>(0);
        final scope = SignalScope();
        Signal<int>? owned;
        Signal<int>? mapped;
        Object? caught;
        var transformCalls = 0;

        scope.run(() {
          owned = Signal<int>(1); // disposed together with the scope
          try {
            mapped = source.map((v) {
              transformCalls++;
              // Call 1 is the construction-time read; call 2 is the eager
              // delivery `listen` runs before returning the subscription.
              if (transformCalls > 1) {
                scope.dispose();
                return owned!.value *
                    2; // StateError: Signal has been disposed.
              }
              return v * 2;
            });
          } catch (e) {
            caught = e;
          }
        });

        expect(
          caught,
          isA<StateError>(),
          reason: 'the throw reaches the caller',
        );
        expect(
          mapped,
          isNull,
          reason: 'map threw before returning the derived',
        );
        final callsAfterSetup = transformCalls;
        expect(
          () => source.value = 1,
          returnsNormally,
          reason: 'a leaked listener would re-enter the throwing transform',
        );
        expect(
          transformCalls,
          callsAfterSetup,
          reason: 'no listener survived the failed subscribe',
        );
      },
    );

    test(
      'D14: a combined signal whose combiner throws during the eager subscribe leaves no leaked listeners',
      () {
        final a = Signal<int>(0);
        final b = Signal<int>(1);
        final scope = SignalScope();
        Signal<int>? owned;
        Signal<int>? combined;
        Object? caught;
        var combinerCalls = 0;

        scope.run(() {
          owned = Signal<int>(1);
          try {
            combined = Signal.combine(a, b, (x, y) {
              combinerCalls++;
              // Call 1 is the construction-time combine; call 2 runs inside
              // `s1.listen`'s eager delivery.
              if (combinerCalls > 1) {
                scope.dispose();
                return owned!.value + x + y; // StateError
              }
              return x + y;
            });
          } catch (e) {
            caught = e;
          }
        });

        expect(caught, isA<StateError>());
        expect(combined, isNull);
        final callsAfterSetup = combinerCalls;
        expect(
          () => a.value = 2,
          returnsNormally,
          reason: 'a leaked s1 listener would re-enter the throwing combiner',
        );
        expect(
          () => b.value = 2,
          returnsNormally,
          reason: 'a leaked s2 listener would re-enter the throwing combiner',
        );
        expect(
          combinerCalls,
          callsAfterSetup,
          reason: 'no listener survived the failed subscribe',
        );
      },
    );
  });
}
