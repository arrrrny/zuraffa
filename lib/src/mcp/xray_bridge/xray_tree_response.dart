// X-Ray tree response — the JSON shape returned by `GET /xray/tree`.
//
// Pure-Dart, no Flutter dependency. The actual HTTP listener lives in
// `zuraffa_flutter`'s `XRayBridgeServer`; this class is the contract.
//
// Track 4.4 — Spec 035 (issue #184, FR-001).
library;

/// Snapshot of the X-Ray tree at a given moment.
class XRayTreeResponse {
  /// The currently-active view's identifier, or `null` when no view is
  /// mounted (e.g. during boot or route transition).
  final String? activeView;

  /// Flat list of node JSON blobs. Each blob's shape is defined by
  /// `XRayNode.toJson()` (spec 036); the bridge just passes them through
  /// verbatim so the MCP agent receives the full tree.
  final List<Map<String, dynamic>> nodes;

  const XRayTreeResponse({this.activeView, this.nodes = const []});

  /// Canonical empty response (no view mounted, no nodes registered).
  const XRayTreeResponse.empty()
    : activeView = null,
      nodes = const [];

  Map<String, dynamic> toJson() => {
    'activeView': activeView,
    'nodes': nodes,
  };

  factory XRayTreeResponse.fromJson(Map<String, dynamic> json) {
    return XRayTreeResponse(
      activeView: json['activeView'] as String?,
      nodes: ((json['nodes'] as List<dynamic>?) ?? const [])
          .map((n) => Map<String, dynamic>.from(n as Map))
          .toList(),
    );
  }
}
