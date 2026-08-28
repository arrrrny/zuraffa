/// Rendered View — a live, interactive UI instance produced by the agent (spec
/// Key Entities).
///
/// Identified by a [viewId]; may be replaced, composed with host chrome, or
/// persisted as a mission result (FR-008).
library;

import 'ui_vocabulary_schema.dart';

/// A live, interactive UI instance produced by the agent (spec Key Entities).
class RenderedView {
  /// Unique identifier returned by the render tool (FR-001).
  final String viewId;

  /// The validated tree.
  final UiNode tree;

  /// Schema version under which the tree was validated (FR-008).
  final String schemaVersion;

  /// Content hash of the tree's canonical representation (FR-008).
  final String contentHash;

  /// Where the host UI should mount this view relative to its chrome
  /// (FR-007 — "coexist with host application's static chrome"). The host
  /// owns the chrome; the agent-rendered view occupies the named slot.
  final String renderSlot;

  /// Optional presentation hint forwarded from the agent (FR-001).
  final String? hint;

  /// `true` when this view has not been superseded by a later render call
  /// (Edge Cases — "two rapid ui.render calls race" — last call wins).
  bool isActive;

  RenderedView({
    required this.viewId,
    required this.tree,
    required this.schemaVersion,
    required this.contentHash,
    this.renderSlot = 'mission-canvas',
    this.hint,
    this.isActive = true,
  });

  @override
  String toString() =>
      'RenderedView($viewId slot=$renderSlot hash=$contentHash active=$isActive)';
}

/// Computes a stable content hash for a [UiNode] tree (FR-008).
///
/// Pure-Dart — no `package:crypto` dependency required. Uses a deterministic
/// stringification (canonical ordering of map entries) then a 64-bit FNV-1a
/// hash formatted as hex. Good enough for replay/audit trace deduplication.
String computeContentHash(UiNode tree) {
  final canonical = _canonicalize(tree);
  // 64-bit FNV-1a.
  var hash = 0xcbf29ce484222325;
  for (final byte in canonical.codeUnits) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

String _canonicalize(UiNode node) {
  final buf = StringBuffer();
  buf.write('{type:${node.type}');
  if (node.styleToken != null) buf.write(',style:${node.styleToken}');
  if (node.actionId != null) {
    buf.write(',action:${node.actionId}');
    buf.write(',tier:${node.actionTier ?? ActionTier.safe}');
  }
  if (node.props.isNotEmpty) {
    final keys = node.props.keys.toList()..sort();
    buf.write(',props:{');
    for (var i = 0; i < keys.length; i++) {
      if (i > 0) buf.write(',');
      final v = node.props[keys[i]];
      buf.write('${keys[i]}:${v is String ? '"$v"' : v}');
    }
    buf.write('}');
  }
  if (node.children.isNotEmpty) {
    buf.write(',children:[');
    for (var i = 0; i < node.children.length; i++) {
      if (i > 0) buf.write(',');
      buf.write(_canonicalize(node.children[i]));
    }
    buf.write(']');
  }
  buf.write('}');
  return buf.toString();
}
