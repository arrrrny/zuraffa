# Red Evidence — XRayShakeDetector abstract interface + no-op default

**Test file**: `test/plugins/xray/xray_shake_detector_test.dart`
**Behavior**: B08 — default no-op + pluggable
**Spec**: FR-004 (shake gesture activation)

## First-run output (before implementation)

```
$ dart test test/plugins/xray/xray_shake_detector_test.dart --reporter compact

Failed to load "test/plugins/xray/xray_shake_detector_test.dart":
  Error: Target of URI doesn't exist: 'package:zuraffa/src/plugins/xray/xray_shake_detector.dart'.
  Error: Method not found: 'XRayShakeDetector'.
```

**Status**: RED ✓

## Resolution

Implementation: `lib/src/plugins/xray/xray_shake_detector.dart` —
abstract `XRayShakeDetector` class with a static `instance` singleton defaulting
to a `_NoOpShakeDetector` (empty `shakes` stream).

Subsequent run (green):
```
00:00 +3: All tests passed!
```
