import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Global toggle for X-Ray mode.
///
/// When disabled (default), XRayScope and XRayNode are transparent
/// pass-through widgets — zero allocations for tree building.
/// When enabled, they register nodes and build a traversable tree.
///
/// In release mode, [enable()] is a no-op and [isEnabled] is always
/// false — zero code path executes.
class XRayMode {
  XRayMode._();

  static bool _enabled = false;
  static final ValueNotifier<bool> _notifier = ValueNotifier<bool>(false);

  /// Notifier that updates when X-Ray mode is toggled.
  ///
  /// Scopes can listen to this to refresh their active state without remounting.
  static ValueNotifier<bool> get notifier => _notifier;

  /// Path to the persistent X-Ray config file.
  /// Shared with [XrayCommand] in the CLI layer.
  @visibleForTesting
  static String get configPath => '.dart_tool/zuraffa/xray.json';

  /// Whether X-Ray mode is currently active.
  ///
  /// Always returns `false` in release mode regardless of internal state.
  static bool get isEnabled {
    if (kReleaseMode) return false;
    return _enabled;
  }

  /// Enable X-Ray mode. Nodes will register with their parent scope.
  ///
  /// This is a no-op in release mode.
  static void enable() {
    if (kReleaseMode) return;
    _enabled = true;
    _notifier.value = true;
  }

  /// Disable X-Ray mode. All scopes stop tracking.
  static void disable() {
    _enabled = false;
    _notifier.value = false;
  }

  /// Toggle X-Ray mode.
  static void toggle() {
    if (kReleaseMode) return;
    if (_enabled) {
      disable();
    } else {
      enable();
    }
  }

  /// Load configuration from the `zfa xray enable` flag file.
  ///
  /// Call this in your app's `main()` or `initState` to respect
  /// the CLI-set flag:
  /// ```dart
  /// void main() {
  ///   XRayMode.loadConfig();
  ///   runApp(MyApp());
  /// }
  /// ```
  static void loadConfig() {
    if (kReleaseMode) return;
    try {
      final file = File(configPath);
      if (!file.existsSync()) return;
      final content = file.readAsStringSync();
      final config = json.decode(content) as Map<String, dynamic>;
      if (config['enabled'] == true) {
        _enabled = true;
        _notifier.value = true;
      }
    } catch (_) {
      // Config file missing or malformed — ignore silently.
    }
  }

  /// Reset for testing.
  @visibleForTesting
  static void reset() {
    _enabled = false;
    _notifier.value = false;
  }
}
