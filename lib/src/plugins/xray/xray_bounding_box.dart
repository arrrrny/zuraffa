// X-Ray bounding box — a single box rendered over a node: rect + label +
// color.
//
// Pure-Dart, no Flutter dependency. Immutable.
//
// Track 4.2 — Spec 036 (issue #181, FR-002, FR-003).
library;

import 'xray_box_color.dart';
import 'xray_box_label.dart';
import 'xray_node.dart';

/// Pure-Dart rect (no Flutter Rect dependency so the model lives in
/// pure-Dart core).
class XRayRect {
  final double left;
  final double top;
  final double width;
  final double height;

  const XRayRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() => {
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };

  factory XRayRect.fromJson(Map<String, dynamic> json) {
    double numOrZero(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
    return XRayRect(
      left: numOrZero(json['left']),
      top: numOrZero(json['top']),
      width: numOrZero(json['width']),
      height: numOrZero(json['height']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XRayRect &&
          left == other.left &&
          top == other.top &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(left, top, width, height);
}

/// A single bounding box rendered over an [XRayNode] in the X-Ray overlay.
///
/// Pure-data: the Flutter painter consumes this and paints it on the
/// OverlayEntry. The MCP bridge (Track 4.4) serializes this list to JSON
/// so an agent can request the current overlay snapshot.
class XRayBoundingBox {
  /// The node's id (e.g. `"ProfileViewNode.editProfileButton"`).
  final String nodeId;

  /// The view type (used for color coding).
  final String viewType;

  /// The rect in screen coordinates.
  final XRayRect rect;

  /// The ARGB int color (from [XRayBoxColor.forViewType]).
  final int color;

  /// The pre-formatted inline label string.
  final String label;

  const XRayBoundingBox({
    required this.nodeId,
    required this.viewType,
    required this.rect,
    required this.color,
    required this.label,
  });

  /// Factory: derive the color and label from the node + rect.
  factory XRayBoundingBox.fromNode(XRayNode node, {required XRayRect rect}) {
    final color = XRayBoxColor.forViewType(node.viewType);
    final label = XRayBoxLabel(
      nodeId: node.id,
      status: node.enabled ? 'enabled' : 'disabled',
      boundAction: node.boundAction,
      stateSummary: node.stateSummary,
    ).format();
    return XRayBoundingBox(
      nodeId: node.id,
      viewType: node.viewType,
      rect: rect,
      color: color,
      label: label,
    );
  }

  Map<String, dynamic> toJson() => {
    'nodeId': nodeId,
    'viewType': viewType,
    'rect': rect.toJson(),
    'color': color,
    'label': label,
  };

  factory XRayBoundingBox.fromJson(Map<String, dynamic> json) {
    return XRayBoundingBox(
      nodeId: json['nodeId'] as String,
      viewType: json['viewType'] as String,
      rect: XRayRect.fromJson(
        (json['rect'] as Map<String, dynamic>?) ?? const {},
      ),
      color: (json['color'] as num).toInt(),
      label: json['label'] as String,
    );
  }
}
