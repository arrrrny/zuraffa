// Shake gesture detector for activating X-Ray mode.
//
// Listens to accelerometer event maps and fires [onShake] when a
// shake pattern is detected.

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Callback for shake events.
typedef ShakeCallback = void Function();

/// Detects device shake gestures from an accelerometer event stream.
class ShakeDetector {
  /// Minimum acceleration magnitude (m/s²) to count as a spike.
  final double threshold;

  /// Number of spikes required within [shakeCountWindow].
  final int shakeCount;

  /// Time window in which [shakeCount] spikes must occur.
  final Duration shakeCountWindow;

  /// Called when a shake is detected.
  final ShakeCallback onShake;

  StreamSubscription? _subscription;
  final List<DateTime> _spikeTimes = [];
  bool _running = false;

  ShakeDetector({
    this.threshold = 12.0,
    this.shakeCount = 3,
    this.shakeCountWindow = const Duration(milliseconds: 600),
    required this.onShake,
  });

  /// Start listening to the given accelerometer [eventStream].
  void start(Stream<Map<String, double>> eventStream) {
    assert(
      kDebugMode || kProfileMode,
      'ShakeDetector is only for debug/profile mode',
    );
    if (!(kDebugMode || kProfileMode)) return;
    stop();
    _subscription = eventStream.listen(_handleEvent);
    _running = true;
  }

  /// Stop listening.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _spikeTimes.clear();
    _running = false;
  }

  /// Whether the detector is currently running.
  bool get isRunning => _running;

  void _handleEvent(Map<String, double> event) {
    final x = event['x'] ?? 0.0;
    final y = event['y'] ?? 0.0;
    final z = event['z'] ?? 0.0;
    final magnitude = x * x + y * y + z * z;

    if (magnitude > threshold * threshold) {
      final now = DateTime.now();
      _spikeTimes.add(now);

      _spikeTimes.removeWhere((t) => now.difference(t) > shakeCountWindow);

      if (_spikeTimes.length >= shakeCount) {
        _spikeTimes.clear();
        onShake();
      }
    }
  }

  /// Reset internal state.
  @visibleForTesting
  void reset() {
    stop();
  }
}
