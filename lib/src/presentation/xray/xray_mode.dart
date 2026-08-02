import 'package:flutter/foundation.dart';

/// Global toggle for X-Ray mode.
///
/// When disabled (default), XRayScope and XRayNode are transparent
/// pass-through widgets — zero allocations for tree building.
/// When enabled, they register nodes and build a traversable tree.
///
/// Later tracks wire this to a debug flag or MCP command.
class XRayMode {
  XRayMode._();

  static bool _enabled = false;

  /// Whether X-Ray mode is currently active.
  static bool get isEnabled => _enabled;

  /// Enable X-Ray mode. Nodes will register with their parent scope.
  static void enable() {
    if (kDebugMode) {
      _enabled = true;
    }
  }

  /// Disable X-Ray mode. All scopes stop tracking.
  static void disable() {
    _enabled = false;
  }

  /// Reset for testing.
  @visibleForTesting
  static void reset() {
    _enabled = false;
  }
}
