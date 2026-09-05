// X-Ray node — the pure-Dart data model for a single node in the X-Ray tree.
//
// Each `XRayNode` corresponds to a registered widget in the live Flutter app
// (Track 4.1 — `zuraffa_flutter` provides the `XRayNode<T>` widget that wraps
// a child widget and registers itself with the overlay). This pure-Dart
// data class is what the MCP bridge serializes, what the overlay paints a
// bounding box for, and what the detail panel dumps to JSON.
//
// Pure-Dart, no Flutter dependency. Immutable.
//
// Track 4.2 — Spec 036 (issue #181, FR-002 / FR-003).
library;

import 'xray_state_summary.dart';

/// One node in the X-Ray widget tree.
///
/// The [id] is the deterministic widget identifier produced by
/// `zuraffa_flutter`'s `XRayScope` (e.g.
/// `"ProfileViewNode.editProfileButton"`). [viewType] is the type of the
/// surrounding view (e.g. `"ProfileView"`) used to color-code the box.
/// [enabled] is the node's interactability flag (e.g. disabled buttons).
/// [boundAction] is the optional callback name attached to interactive
/// nodes (e.g. `"onEditTapped"`). [stateSummary] is the at-a-glance
/// SignalSlice state. [children] is the recursive child nodes (for the
/// MCP tree serialization).
class XRayNode {
  /// Deterministic widget id (e.g. `"ProfileViewNode.editProfileButton"`).
  final String id;

  /// Surrounding view type (e.g. `"ProfileView"`).
  final String viewType;

  /// Whether the underlying widget is currently enabled.
  final bool enabled;

  /// Optional bound action name (e.g. `"onEditTapped"`).
  final String? boundAction;

  /// At-a-glance SignalSlice state summary.
  final XRayStateSummary stateSummary;

  /// The owning feature contract id (spec 1098, issue #1098), when the
  /// node is attributed to a feature — the deck can then answer
  /// file→feature, not only file→layer. Null on legacy nodes.
  final String? featureId;

  /// Recursive child nodes (for the MCP tree).
  final List<XRayNode> children;

  const XRayNode({
    required this.id,
    required this.viewType,
    required this.enabled,
    required this.stateSummary,
    this.boundAction,
    this.featureId,
    this.children = const <XRayNode>[],
  });

  /// Canonical JSON serialization (consumed by the MCP `GET /xray/tree`
  /// endpoint in Track 4.4 — spec 035).
  Map<String, dynamic> toJson() => {
    'id': id,
    'viewType': viewType,
    'enabled': enabled,
    if (boundAction != null) 'boundAction': boundAction,
    if (featureId != null) 'featureId': featureId,
    'stateSummary': stateSummary.toJson(),
    'children': children.map((c) => c.toJson()).toList(),
  };

  /// Deserialize from JSON.
  factory XRayNode.fromJson(Map<String, dynamic> json) {
    return XRayNode(
      id: json['id'] as String,
      viewType: json['viewType'] as String,
      enabled: json['enabled'] as bool? ?? false,
      boundAction: json['boundAction'] as String?,
      stateSummary: XRayStateSummary.fromJson(
        (json['stateSummary'] as Map<String, dynamic>?) ?? const {},
      ),
      featureId: json['featureId'] as String?,
      children: ((json['children'] as List<dynamic>?) ?? const [])
          .map((c) => XRayNode.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String toString() => 'XRayNode($id, $viewType, ${stateSummary.statusWord})';
}
