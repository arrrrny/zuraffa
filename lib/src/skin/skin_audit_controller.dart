/// SkinAuditController — the pure bus core the debug chrome renders
/// (issue #1102).
///
/// The pilot's `skinAuditBus` was a `ValueNotifier` the banner
/// listened to; the productized bus core is pure Dart (the emitted
/// `SkinAuditBus` ValueNotifier bridges it for the Flutter side, so
/// `package:zuraffa` stays Flutter-free — Constitution VII).
///
/// Two behaviors are load-bearing:
///
/// * **Change detection** — `publish` returns whether the live
///   violation set actually changed. The chrome rebuilds only on a
///   real change: no banner churn while the same chaos edit stays on
///   screen, and the pilot's "revert + hot reload → banner clears on
///   the next frame" is one publish of an empty list away.
/// * **Bounded history** — the pilot's violations were a growing
///   list; the productized bus keeps a capped ring (the banner shows
///   the LIVE set, receipts/diagnostics read the history tail).
library;

import 'skin_violation.dart';

class SkinAuditController {
  /// Creates a bus core. [historyLimit] caps the retained history
  /// ring (default 50 — enough to diagnose a session, bounded enough
  /// to never grow unbounded in a long debug run).
  SkinAuditController({int historyLimit = 50}) : _historyLimit = historyLimit;

  final int _historyLimit;
  final List<void Function()> _listeners = [];
  final List<List<SkinViolation>> _history = [];
  List<SkinViolation> _violations = const [];

  /// The live violations (most recent publish), unmodifiable.
  List<SkinViolation> get violations => List.unmodifiable(_violations);

  /// Whether the banner should be visible.
  bool get hasViolations => _violations.isNotEmpty;

  /// The bounded history of published sets, most recent FIRST.
  List<List<SkinViolation>> get history => List.unmodifiable(_history.reversed);

  /// Replaces the live violation set. Returns `true` when the set
  /// actually changed (and listeners were notified), `false` for a
  /// no-op publish.
  ///
  /// Publishing an empty list clears the banner — the revert path.
  bool publish(List<SkinViolation> violations) {
    final changed = !_equal(_violations, violations);
    if (!changed) return false;
    _violations = List.unmodifiable(violations);
    if (_violations.isNotEmpty || _history.isNotEmpty) {
      // Record every real transition, including the clear (the
      // revert receipt), but never a no-op.
      _history.add(List.unmodifiable(violations));
      while (_history.length > _historyLimit) {
        _history.removeAt(0);
      }
    }
    _notify();
    return true;
  }

  /// Clears the live set. Returns whether anything changed.
  bool clear() => publish(const []);

  /// Subscribes to changes (the chrome's ValueNotifier bridge and
  /// test lanes use this).
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  /// Unsubscribes.
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  /// Drops every listener (widget teardown / test teardown).
  void dispose() {
    _listeners.clear();
  }

  void _notify() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  static bool _equal(List<SkinViolation> a, List<SkinViolation> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
