// Metadata registry for X-Ray nodes.
//
// Provides a way to attach optional runtime information to X-Ray nodes,
// such as bound action names and SignalSlice state snapshots.

import 'package:flutter/foundation.dart';

/// Optional metadata for an X-Ray node.
class XRayNodeMetadata {
  /// Human-readable name of the bound action (e.g. 'onSaveTapped').
  final String? actionName;

  /// Whether the node's action is currently enabled.
  final bool isEnabled;

  /// Snapshot of any associated state (e.g. from a SignalSlice).
  ///
  /// This can be a map with keys like 'data', 'error', 'loading'.
  final Map<String, dynamic>? stateJson;

  const XRayNodeMetadata({
    this.actionName,
    this.isEnabled = true,
    this.stateJson,
  });

  /// Returns a JSON-serializable representation.
  Map<String, dynamic> toJson() {
    return {
      if (actionName != null) 'action': actionName,
      'enabled': isEnabled,
      if (stateJson != null) 'state': stateJson,
    };
  }

  @override
  String toString() => 'XRayNodeMetadata(${toJson()})';
}

/// Global registry for [XRayNodeMetadata] instances.
///
/// Controllers and presenters call [register] to attach metadata
/// to X-Ray nodes. The overlay queries this registry when rendering.
class XRayMetadataRegistry {
  XRayMetadataRegistry._();

  static final Map<String, XRayNodeMetadata> _metadata = {};

  /// Register or update metadata for the node identified by [nodeId].
  static void register(String nodeId, XRayNodeMetadata metadata) {
    assert(
      kDebugMode || kProfileMode,
      'XRayMetadataRegistry is only available in debug/profile mode',
    );
    if (kDebugMode || kProfileMode) {
      _metadata[nodeId] = metadata;
    }
  }

  /// Remove metadata for the node identified by [nodeId].
  static void unregister(String nodeId) {
    assert(
      kDebugMode || kProfileMode,
      'XRayMetadataRegistry is only available in debug/profile mode',
    );
    if (kDebugMode || kProfileMode) {
      _metadata.remove(nodeId);
    }
  }

  /// Look up metadata for the node identified by [nodeId].
  static XRayNodeMetadata? forNode(String nodeId) {
    assert(
      kDebugMode || kProfileMode,
      'XRayMetadataRegistry is only available in debug/profile mode',
    );
    if (kDebugMode || kProfileMode) {
      return _metadata[nodeId];
    }
    return null;
  }

  /// Clear all registered metadata. Useful in tests.
  @visibleForTesting
  static void clear() {
    _metadata.clear();
  }
}
