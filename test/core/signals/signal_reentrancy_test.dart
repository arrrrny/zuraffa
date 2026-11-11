import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('US5 · Notification path reentrancy hardening', () {
    test('E1: signal disposed by listener A mid-notification stops B, no error escapes', () {
      final s = Signal<int>(0);
      var aCalls = 0;
      var bCalls = 0;

      s.listen((v) {
        aCalls++;
        if (v == 1) s.dispose(); // hostile: dispose mid-notification
      });
      s.listen((_) => bCalls++);

      // Eager subscribe-time deliveries: both saw 0.
      expect(aCalls, 1);
      expect(bCalls, 1);

      s.value = 1; // notification: A disposes mid-flight
      expect(aCalls, 2);
      expect(bCalls, 1, reason: 'B must not receive a value from a signal disposed mid-notification');
      expect(s.isDisposed, isTrue);
      expect(() => s.listen((_) {}), throwsStateError, reason: 'disposed signal rejects new listeners');
    });

    test('E2: listener cancelled by A mid-notification receives nothing from that notification', () {
      final s = Signal<int>(0);
      var bCalls = 0;
      late SignalSubscription bSub;
      var aCalls = 0;

      s.listen((v) {
        aCalls++;
        if (v == 10) {
          bSub.cancel(); // cancel B BEFORE its delivery in the same notification
        }
      });
      bSub = s.listen((_) => bCalls++);

      // Eager deliveries: a saw 0 (aCalls 1, no cancel since v != 10), b saw 0.
      expect(aCalls, 1);
      expect(bCalls, 1);

      s.value = 10; // notification: A cancels B mid-flight
      expect(aCalls, 2);
      expect(bCalls, 1, reason: 'B was cancelled before its delivery of 10');
    });

    test('E3: disposing parent SignalResult disposes its flatMap-derived output (no orphan)', () {
      final parent = SignalResult<int>.success(1);
      final derived = parent.flatMap((v) => SignalResult<int>.success(v * 10));

      expect(derived.isDisposed, isFalse);
      parent.dispose();
      expect(derived.isDisposed, isTrue, reason: 'parent disposal must cascade to derived output');

      // and the old orphan behavior is gone: derived rejects writes
      expect(() => derived.emitSuccess(99), throwsStateError);
    });

    test('E3b: flatMap output disposal while parent alive stops propagation', () {
      final parent = SignalResult<int>.success(1);
      final derived = parent.flatMap((v) => SignalResult<int>.success(v * 10));
      var derivedNotifications = 0;
      derived.listen((_) => derivedNotifications++); // eager: 1

      derived.dispose();
      parent.emitSuccess(5); // parent still alive, but derived is gone
      expect(derivedNotifications, 1, reason: 'no propagation into a disposed output');
      expect(parent.isDisposed, isFalse);
    });

    test('E4: double dispose of a signal is safe', () {
      final s = Signal<int>(0);
      s.dispose();
      s.dispose();
      expect(s.isDisposed, isTrue);
    });
  });
}
