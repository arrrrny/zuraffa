// X-Ray Bridge scope holder — web-safe (no dart:io).
//
// Holds a reference to the currently active [XRayScopeState] so the
// bridge server (or any other consumer) can serialize the tree.
//
// This file is intentionally split out from [xray_bridge_server.dart]
// (which depends on dart:io) so that [XRayScopeState] can self-register
// without pulling dart:io into the web-safe barrel. The barrel
// `xray.dart` exports this file; it does NOT export
// `xray_bridge_server.dart`.
//
// Set this in your app's widget tree (e.g. via [XRayScope]'s
// [XRayScopeState.initState]) so the bridge can serialize the tree.
// In release mode, every method is a no-op.

import 'package:flutter/foundation.dart';

import 'xray_scope.dart';

/// Holds a reference to the currently active [XRayScopeState].
///
/// Set this in your app's widget tree (e.g. in [XRayScopeState]'s
/// initState — which [XRayScope] does automatically as of issue #360)
/// so the bridge can serialize the tree.
///
/// Supports nested scopes: when a child scope disposes, the parent scope
/// is restored as the active scope.
class XRayBridgeScopeHolder {
  XRayBridgeScopeHolder._();

  static final List<XRayScopeState> _scopeStack = [];

  /// Register the active scope.
  /// If a scope is already active, the new scope becomes active and the
  /// previous scope is preserved in a stack.
  static void setScope(XRayScopeState scope) {
    if (kReleaseMode) return;
    _scopeStack.add(scope);
  }

  /// Clear the specified scope (e.g. on dispose).
  /// If this scope is the active scope, restore the previous scope.
  /// If it's a parent scope being disposed while a child is active,
  /// remove it from the stack but keep the child active.
  static void clearScope(XRayScopeState scope) {
    if (kReleaseMode) return;
    _scopeStack.remove(scope);
  }

  /// Get the current active scope, if any.
  /// Returns the most recently registered scope that hasn't been cleared.
  static XRayScopeState? get activeScope {
    if (kReleaseMode) return null;
    return _scopeStack.isEmpty ? null : _scopeStack.last;
  }

  /// Clear for testing.
  @visibleForTesting
  static void reset() {
    _scopeStack.clear();
  }
}
