// X-Ray activation widget — wraps the app with gesture-based activation.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'xray_mode.dart';
import 'xray_shake_detector.dart';

/// A widget that enables X-Ray mode activation via gestures.
///
/// Supports:
/// - **Two-finger long press**: hold two fingers for [twoFingerDuration].
/// - **Shake**: provide an accelerometer event [accelerometerStream]
///   (e.g. from `sensors_plus`).
///
/// Wrap your app's root widget (above the [Navigator]) with this:
/// ```dart
/// XRayActivation(
///   child: MaterialApp(...),
/// )
/// ```
///
/// In release mode, this is a pure pass-through with zero overhead.
class XRayActivation extends StatefulWidget {
  final Widget child;
  final Duration twoFingerDuration;

  /// Optional stream of accelerometer events for shake detection.
  ///
  /// Each event should be a map with 'x', 'y', 'z' keys (m/s²).
  /// If null, shake detection is disabled.
  ///
  /// Example with `sensors_plus`:
  /// ```dart
  /// import 'package:sensors_plus/sensors_plus.dart';
  ///
  /// XRayActivation(
  ///   accelerometerStream: accelerometerEventStream().map(
  ///     (e) => {'x': e.x, 'y': e.y, 'z': e.z},
  ///   ),
  ///   child: MyApp(),
  /// )
  /// ```
  final Stream<Map<String, double>>? accelerometerStream;

  const XRayActivation({
    super.key,
    required this.child,
    this.twoFingerDuration = const Duration(milliseconds: 500),
    this.accelerometerStream,
  });

  @override
  State<XRayActivation> createState() => _XRayActivationState();
}

class _XRayActivationState extends State<XRayActivation> {
  final Map<int, Offset> _pointers = {};
  Timer? _twoFingerTimer;
  ShakeDetector? _shakeDetector;

  @override
  void initState() {
    super.initState();
    _initShakeDetector();
  }

  @override
  void didUpdateWidget(XRayActivation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accelerometerStream != widget.accelerometerStream) {
      _shakeDetector?.stop();
      _initShakeDetector();
    }
  }

  void _initShakeDetector() {
    final stream = widget.accelerometerStream;
    if (stream == null) return;
    _shakeDetector = ShakeDetector(
      onShake: _toggleXRay,
    )..start(stream);
  }

  @override
  void dispose() {
    _twoFingerTimer?.cancel();
    _shakeDetector?.stop();
    super.dispose();
  }

  void _toggleXRay() {
    setState(() {
      if (XRayMode.isEnabled) {
        XRayMode.disable();
      } else {
        XRayMode.enable();
      }
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length >= 2 && _twoFingerTimer == null) {
      _twoFingerTimer = Timer(widget.twoFingerDuration, () {
        _twoFingerTimer = null;
        _toggleXRay();
      });
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) {
      _twoFingerTimer?.cancel();
      _twoFingerTimer = null;
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) {
      _twoFingerTimer?.cancel();
      _twoFingerTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode && !kProfileMode) {
      return widget.child;
    }

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}