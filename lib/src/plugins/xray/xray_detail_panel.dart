// X-Ray detail panel — the full-state JSON dump shown when a developer
// taps a bounding box (FR-006).
//
// Pure-Dart, no Flutter dependency. Immutable.
//
// Track 4.2 — Spec 036 (issue #181, FR-006).
library;

import 'dart:convert';

import 'xray_node.dart';

/// Tap-to-inspect detail panel payload.
///
/// `fullStateJson` is the canonical, MCP-compatible JSON serialization of
/// the tapped node including its full SignalSlice state (data / error /
/// loading) and recursive children. The Flutter side just `jsonDecode`s
/// and renders; the data side lives here.
class XRayDetailPanel {
  /// The node's id (echoed for the UI).
  final String nodeId;

  /// The full state JSON, as a string (so the Flutter side can pretty-print
  /// or pass it through verbatim to the MCP agent).
  final String fullStateJson;

  const XRayDetailPanel({required this.nodeId, required this.fullStateJson});

  /// Build a panel from a node. Produces a canonical JSON tree.
  factory XRayDetailPanel.fromNode(XRayNode node) {
    // JsonEncoder produces pretty (indented) output for human inspection.
    const encoder = JsonEncoder();
    return XRayDetailPanel(
      nodeId: node.id,
      fullStateJson: encoder.convert(_toNodeMap(node)),
    );
  }

  /// Recursive map builder shared by [fromNode].
  ///
  /// Builds the node map directly instead of re-encoding/decoding each child
  /// to a JSON string and back — the string round-trip was O(n) extra work
  /// per node and produced untyped `dynamic` lists.
  static Map<String, dynamic> _toNodeMap(XRayNode node) {
    final state = <String, dynamic>{
      'data': node.stateSummary.hasData
          ? (node.stateSummary.dataPreview ?? '<data>')
          : null,
      'error': node.stateSummary.hasError
          ? (node.stateSummary.errorPreview ?? '<error>')
          : null,
      'loading': node.stateSummary.isLoading,
    };

    return <String, dynamic>{
      'nodeId': node.id,
      'viewType': node.viewType,
      'enabled': node.enabled,
      if (node.boundAction != null) 'boundAction': node.boundAction,
      'state': state,
      'children': node.children.map(_toNodeMap).toList(),
    };
  }

  Map<String, dynamic> toJson() => {
    'nodeId': nodeId,
    'fullStateJson': fullStateJson,
  };

  factory XRayDetailPanel.fromJson(Map<String, dynamic> json) {
    return XRayDetailPanel(
      nodeId: json['nodeId'] as String,
      fullStateJson: json['fullStateJson'] as String,
    );
  }
}
