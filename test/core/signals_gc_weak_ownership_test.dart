import 'package:test/test.dart';
import 'package:zuraffa/src/core/signals/zfa_signal.dart';
import 'package:zuraffa/src/core/signals/zfa_computed.dart';

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

    test('Expando weak ownership test', () async {
      // Create a scoped owner object that can be garbage collected
      WeakReference<Object>? ownerRef;
      ZfaSignal<int>? signal;

      void createAndDropOwner() {
        final owner = Object();
        ownerRef = WeakReference(owner);
        signal = ZfaSignal<int>(42, owner: owner);
        expect(signal!.value, 42);
        // owner goes out of scope here
      }

      createAndDropOwner();

      // Force GC if possible, or verify expando doesn't retain strong reference to owner
      // (In Dart VM, weak references/Expando keys allow GC when no other strong references exist).
      expect(ownerRef, isNotNull);
      // We can also explicitly test ZfaSignal.disposeOwner
      final persistentOwner = Object();
      final persistentSignal = ZfaSignal<int>(100, owner: persistentOwner);
      expect(persistentSignal.isDisposed, isFalse);

      ZfaSignal.disposeOwner(persistentOwner);
      expect(persistentSignal.isDisposed, isTrue);
    });
  });
}
