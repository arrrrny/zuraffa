// X-Ray tree diff — the WebSocket payload for the X-Ray bridge diff stream.
//
// Track 4.4 — Spec 035 (issue #184, FR-004).
library;

import 'dart:async';

/// Type of change to a single node in the X-Ray tree.
enum XRayDiffType {
  /// A new node was added.
  add,

  /// An existing node was removed.
  remove,

  /// A node's state changed (the data/error/loading summary).
  update;

  /// Canonical lower-case string label for JSON serialization.
  String get label => name;

  /// Parse a string into an [XRayDiffType]. Throws [FormatException] for
  /// unknown values.
  static XRayDiffType fromString(String s) {
    for (final t in XRayDiffType.values) {
      if (t.name == s) return t;
    }
    throw FormatException('Unknown XRayDiffType: "$s"');
  }
}

/// A single change to the X-Ray tree, pushed via the bridge's WebSocket
/// diff stream.
class XRayDiff {
  /// What kind of change happened.
  final XRayDiffType type;

  /// The id of the affected node.
  final String nodeId;

  /// For [XRayDiffType.add] — the added node's serialized form.
  /// `null` for remove / update.
  final Map<String, dynamic>? node;

  /// For [XRayDiffType.update] — the previous state.
  /// `null` for add / remove.
  final Map<String, dynamic>? before;

  /// For [XRayDiffType.update] — the new state.
  /// `null` for add / remove.
  final Map<String, dynamic>? after;

  const XRayDiff({
    required this.type,
    required this.nodeId,
    this.node,
    this.before,
    this.after,
  });

  /// Factory for an add event.
  factory XRayDiff.add({
    required String nodeId,
    required Map<String, dynamic> node,
  }) {
    return XRayDiff(type: XRayDiffType.add, nodeId: nodeId, node: node);
  }

  /// Factory for a remove event.
  factory XRayDiff.remove({required String nodeId}) {
    return XRayDiff(type: XRayDiffType.remove, nodeId: nodeId);
  }

  /// Factory for an update event.
  factory XRayDiff.update({
    required String nodeId,
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
  }) {
    return XRayDiff(
      type: XRayDiffType.update,
      nodeId: nodeId,
      before: before,
      after: after,
    );
  }

  Map<String, dynamic> toJson() {
    final j = <String, dynamic>{
      'type': type.label,
      'nodeId': nodeId,
    };
    if (node != null) j['node'] = node;
    if (before != null) j['before'] = before;
    if (after != null) j['after'] = after;
    return j;
  }

  factory XRayDiff.fromJson(Map<String, dynamic> json) {
    return XRayDiff(
      type: XRayDiffType.fromString(json['type'] as String),
      nodeId: json['nodeId'] as String,
      node: json['node'] as Map<String, dynamic>?,
      before: json['before'] as Map<String, dynamic>?,
      after: json['after'] as Map<String, dynamic>?,
    );
  }
}

/// Broadcast stream of [XRayDiff] events for the X-Ray bridge WebSocket
/// subscribers.
///
/// Pure-Dart; the actual WebSocket transport (the `WebSocketChannel`
/// upgrade) lives in `zuraffa_flutter`'s `XRayBridgeServer`. The Flutter
/// side calls `emitAdd` / `emitRemove` / `emitUpdate` from the live
/// `XRayOverlayState.changes` subscription.
///
/// In release mode, all `emit*` calls are no-ops and `stream` is a
/// const-empty stream (FR-006 / SC-004).
class XRayBridgeDiffStream {
  final bool _isReleaseMode;

  final StreamController<XRayDiff> _controller =
      StreamController<XRayDiff>.broadcast();

  XRayBridgeDiffStream({bool? isReleaseMode})
    : _isReleaseMode = isReleaseMode ?? false;

  /// Broadcast stream of diffs. Subscribers receive every diff emitted
  /// AFTER they subscribe (no replay). Empty in release mode.
  Stream<XRayDiff> get stream => _isReleaseMode
      ? const Stream<XRayDiff>.empty()
      : _controller.stream;

  void emitAdd({
    required String nodeId,
    required Map<String, dynamic> node,
  }) {
    if (_isReleaseMode) return;
    _controller.add(XRayDiff.add(nodeId: nodeId, node: node));
  }

  void emitRemove({required String nodeId}) {
    if (_isReleaseMode) return;
    _controller.add(XRayDiff.remove(nodeId: nodeId));
  }

  void emitUpdate({
    required String nodeId,
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
  }) {
    if (_isReleaseMode) return;
    _controller.add(XRayDiff.update(
      nodeId: nodeId,
      before: before,
      after: after,
    ));
  }

  /// Close the underlying controller. Safe to call multiple times.
  void close() {
    if (!_controller.isClosed) _controller.close();
  }
}
