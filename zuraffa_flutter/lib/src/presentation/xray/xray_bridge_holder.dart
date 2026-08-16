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
class XRayBridgeScopeHolder {
  XRayBridgeScopeHolder._();

  /// Registration stack of live scopes. The most recently mounted scope is
  /// the active one; disposing a nested/sibling scope pops only that entry
  /// so an outer scope stays registered for tree serialization (#360).
  static final List<XRayScopeState> _scopeStack = [];

  /// Register the active scope.
  static void setScope(XRayScopeState scope) {
    if (kReleaseMode) return;
    _scopeStack
      ..remove(scope)
      ..add(scope);
  }

  /// Remove a disposing scope from the registration stack.
  ///
  /// Only [scope] itself is removed — sibling/parent scopes stay
  /// registered, so `activeScope` falls back to the enclosing scope
  /// instead of going null (#360).
  static void clearScope(XRayScopeState scope) {
    if (kReleaseMode) return;
    _scopeStack.remove(scope);
  }

  /// Get the current active scope, if any.
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
