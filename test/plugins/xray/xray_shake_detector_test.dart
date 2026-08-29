// Spec 036 — Track 4.2: XRayShakeDetector abstract interface tests.
//
// Behavior B08: default no-op + pluggable.
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/xray/xray_shake_detector.dart';

void main() {
  // Hold the original instance so we can restore it after each test
  // (the detector is a global singleton, so we MUST clean up).
  final original = XRayShakeDetector.instance;

  tearDown(() {
    XRayShakeDetector.instance = original;
  });

  group('XRayShakeDetector', () {
    test('default instance is a no-op detector with empty shakes stream',
        () async {
      // Reset to the default no-op
      XRayShakeDetector.instance = const _NoOpShakeDetectorForTest();
      var emitted = 0;
      final sub = XRayShakeDetector.instance.shakes.listen((_) {
        emitted++;
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(emitted, 0,
          reason: 'no-op detector MUST NOT emit any shake events');
    });

    test('instance is pluggable — custom detector is observable', () async {
      final custom = _FakeShakeDetector();
      XRayShakeDetector.instance = custom;
      final completer = Completer<void>();
      final sub = XRayShakeDetector.instance.shakes.listen(completer.complete);
      custom.emit();
      await completer.future.timeout(const Duration(seconds: 1));
      await sub.cancel();
    });

    test('default instance shakes stream is empty Stream (const)', () {
      XRayShakeDetector.instance = const _NoOpShakeDetectorForTest();
      // Drain the stream — should complete immediately.
      expect(
        XRayShakeDetector.instance.shakes,
        emitsDone,
      );
    });
  });
}

class _NoOpShakeDetectorForTest implements XRayShakeDetector {
  const _NoOpShakeDetectorForTest();
  @override
  Stream<void> get shakes => const Stream<void>.empty();
}

class _FakeShakeDetector implements XRayShakeDetector {
  final _controller = StreamController<void>.broadcast();
  @override
  Stream<void> get shakes => _controller.stream;
  void emit() => _controller.add(null);
  void dispose() => _controller.close();
}
