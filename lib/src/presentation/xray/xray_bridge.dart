// X-Ray Bridge — connects external AI agents to the live X-Ray tree.
//
// Provides JSON tree serialization, bound-action invocation, and
// Control Deck mock injection for MCP / HTTP bridge endpoints.
//
// Security: every public method is a no-op in release mode.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'xray_node_metadata.dart';
import 'xray_scope.dart';

// ------------------------------------------------------------------
// Types
// ------------------------------------------------------------------

/// A serializable snapshot of a single X-Ray node.
class XRayTreeNodeJson {
  /// Deterministic node ID, e.g. "ProductView.actionButton".
  final String id;

  /// The enum value name (e.g. "actionButton").
  final String enumName;

  /// Bound action name from [XRayMetadataRegistry], if any.
  final String? actionName;

  /// Whether the node's action is enabled.
  final bool isEnabled;

  /// Snapshot of associated state (e.g. loading, data, error).
  final Map<String, dynamic>? state;

  const XRayTreeNodeJson({
    required this.id,
    required this.enumName,
    this.actionName,
    this.isEnabled = true,
    this.state,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': enumName,
        if (actionName != null) 'boundAction': actionName,
        'enabled': isEnabled,
        if (state != null) 'state': state,
      };
}

/// Full JSON response for `GET /xray/tree`.
class XRayTreeJson {
  /// The active view's scope ID.
  final String activeView;

  /// All registered nodes in registration order.
  final List<XRayTreeNodeJson> nodes;

  const XRayTreeJson({
    required this.activeView,
    required this.nodes,
  });

  Map<String, dynamic> toJson() => {
        'activeView': activeView,
        'nodes': nodes.map((n) => n.toJson()).toList(),
      };
}

// ------------------------------------------------------------------
// Action registry
// ------------------------------------------------------------------

/// Callback signature for a bound action.
typedef XRayBoundAction = void Function(Map<String, dynamic> payload);

/// Global registry that maps node IDs to their bound-action callbacks.
///
/// Controllers call [register] during initialization so the bridge
/// can invoke actions by node ID.
class XRayActionRegistry {
  XRayActionRegistry._();

  static final Map<String, XRayBoundAction> _actions = {};

  /// Register a bound action for the node identified by [nodeId].
  static void register(String nodeId, XRayBoundAction action) {
    assert(
      !kReleaseMode,
      'XRayActionRegistry is only available in debug/profile mode',
    );
    if (kReleaseMode) return;
    _actions[nodeId] = action;
  }

  /// Unregister a bound action.
  static void unregister(String nodeId) {
    if (kReleaseMode) return;
    _actions.remove(nodeId);
  }

  /// Invoke the action for [nodeId] with an optional [payload].
  ///
  /// Returns `true` if the action was found and invoked, `false` otherwise.
  static bool invoke(String nodeId, [Map<String, dynamic>? payload]) {
    if (kReleaseMode) return false;
    final action = _actions[nodeId];
    if (action == null) return false;
    action(payload ?? const {});
    return true;
  }

  /// List all registered node IDs (useful for 404 error messages).
  static List<String> get registeredIds {
    if (kReleaseMode) return const [];
    return List.unmodifiable(_actions.keys);
  }

  /// Clear all registered actions (for testing).
  @visibleForTesting
  static void clear() {
    _actions.clear();
  }
}

// ------------------------------------------------------------------
// Mock injector registry (Control Deck bridge target)
// ------------------------------------------------------------------

/// Callback invoked when an external agent triggers a mock by name.
typedef XRayMockInjectorCallback = void Function(dynamic payload);

/// Global registry that maps mock names to their injector callbacks.
class XRayMockInjectorRegistry {
  XRayMockInjectorRegistry._();

  static final Map<String, XRayMockInjectorCallback> _injectors = {};

  /// Register an injector for a given mock name.
  static void register(String mockName, XRayMockInjectorCallback injector) {
    if (kReleaseMode) return;
    _injectors[mockName] = injector;
  }

  /// Unregister an injector.
  static void unregister(String mockName) {
    if (kReleaseMode) return;
    _injectors.remove(mockName);
  }

  /// Invoke the injector for [mockName] with [payload].
  ///
  /// Returns `true` if the mock was found and triggered.
  static bool trigger(String mockName, [dynamic payload]) {
    if (kReleaseMode) return false;
    final injector = _injectors[mockName];
    if (injector == null) return false;
    injector(payload);
    return true;
  }

  /// List all registered mock names.
  static List<String> get registeredNames {
    if (kReleaseMode) return const [];
    return List.unmodifiable(_injectors.keys);
  }

  /// Clear all registered injectors (for testing).
  @visibleForTesting
  static void clear() {
    _injectors.clear();
  }
}

// ------------------------------------------------------------------
// Bridge controller — orchestrates tree snapshot + diff stream
// ------------------------------------------------------------------

/// Events emitted by the X-Ray bridge when the tree changes.
enum XRayBridgeEventType { added, removed, updated }

/// A single tree diff event pushed over WebSocket.
class XRayTreeDiff {
  final XRayBridgeEventType type;
  final String nodeId;
  final XRayTreeNodeJson? node;

  const XRayTreeDiff({
    required this.type,
    required this.nodeId,
    this.node,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'nodeId': nodeId,
        if (node != null) 'node': node!.toJson(),
      };
}

/// Stream controller that broadcasts tree change events.
///
/// The [XRayScope] integration calls [notifyTreeChanged] when
/// nodes are registered or unregistered, and the bridge server
/// pushes these diffs to connected WebSocket clients.
class XRayBridgeStream {
  XRayBridgeStream._();

  static final StreamController<XRayTreeDiff> _controller =
      StreamController<XRayTreeDiff>.broadcast();

  /// Subscribe to tree change events.
  static Stream<XRayTreeDiff> get stream => _controller.stream;

  /// Whether any listeners are subscribed.
  static bool get hasListeners => _controller.hasListener;

  /// Emit a diff event. Called by [XRayScopeState] when nodes change.
  static void emit(XRayTreeDiff diff) {
    if (kReleaseMode) return;
    if (_controller.hasListener) {
      _controller.add(diff);
    }
  }

  /// Close the stream (for testing).
  @visibleForTesting
  static Future<void> close() => _controller.close();
}

// ------------------------------------------------------------------
// Tree serialization
// ------------------------------------------------------------------

/// Serializes an [XRayScopeState] tree into a JSON-ready structure.
///
/// Enriches each node with metadata from [XRayMetadataRegistry]
/// (action name, enabled state, state snapshot).
XRayTreeJson serializeXRayTree(XRayScopeState scope) {
  final nodes = scope.tree.map((info) {
    final meta = XRayMetadataRegistry.forNode(info.id);
    return XRayTreeNodeJson(
      id: info.id,
      enumName: info.enumName,
      actionName: meta?.actionName,
      isEnabled: meta?.isEnabled ?? true,
      state: meta?.stateJson,
    );
  }).toList();

  return XRayTreeJson(activeView: scope.viewId, nodes: nodes);
}
