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
  });
}
