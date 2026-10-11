/// Spec 968 — the virtual clock (U2, A4): deterministic simulated time.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/simulation/worlds/virtual_clock.dart';

void main() {
  group('VirtualClock', () {
    test('the epoch is seed-derived and deterministic', () {
      final a = VirtualClock(968);
      final b = VirtualClock(968);
      expect(a.nowMs, b.nowMs);
      expect(a.epochMs, b.epochMs);
      expect(a.elapsedMs, 0);
      // Distinct seeds get distinct epochs (deterministic spread).
      expect(VirtualClock(1).epochMs, isNot(VirtualClock(2).epochMs));
    });

    test('advance accumulates and reports the new now', () {
      final clock = VirtualClock(42);
      final t1 = clock.advance(50);
      expect(clock.elapsedMs, 50);
      expect(t1, clock.nowMs);
      clock.advance(100);
      expect(clock.elapsedMs, 150);
    });

    test('negative advances are clamped (time only moves forward)', () {
      final clock = VirtualClock(42);
      clock.advance(75);
      clock.advance(-1000);
      expect(clock.elapsedMs, 75);
    });

    test('nowIso renders a real UTC instant', () {
      final clock = VirtualClock.atEpoch(0);
      expect(clock.nowIso, startsWith('1970-01-01T00:00:00'));
    });

    test('same seed → same time sequence across clocks', () {
      final a = VirtualClock(7);
      final b = VirtualClock(7);
      for (final wait in [5, 50, 100, 200, 1000]) {
        expect(a.advance(wait), b.advance(wait));
      }
      expect(a.nowMs, b.nowMs);
    });
  });
}
