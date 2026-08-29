// X-Ray shake detector — abstract platform interface.
//
// Pure-Dart can't detect accelerometer shake gestures (no platform access).
// This file defines the interface + a default no-op implementation; the
// Flutter `zuraffa_flutter` package installs a real platform detector at
// boot via `XRayShakeDetector.instance = ...`.
//
// The CLI / codegen can reference the interface without pulling Flutter.
//
// Track 4.2 — Spec 036 (issue #181, FR-004 — shake gesture activation).
library;

import 'dart:async';

/// Abstract shake-detector interface.
///
/// Implementations live in `zuraffa_flutter` (Flutter platform channels
/// for accelerometer data). The pure-Dart default is [instance] which
/// returns an empty stream (no-op).
abstract class XRayShakeDetector {
  /// Stream of shake events. Emits `null` (we only care about events, not
  /// their magnitude).
  Stream<void> get shakes;

  /// Global singleton — settable by the Flutter app at boot.
  ///
  /// Defaults to a no-op detector so the pure-Dart CLI can call
  /// `XRayShakeDetector.instance.shakes.listen(...)` without crashing;
  /// it just never receives any events.
  static XRayShakeDetector instance = const _NoOpShakeDetector();
}

/// Default no-op detector — empty `shakes` stream.
class _NoOpShakeDetector implements XRayShakeDetector {
  const _NoOpShakeDetector();
  @override
  Stream<void> get shakes => const Stream<void>.empty();
}
