// X-Ray overlay state — the pure-Dart registry of active nodes + a
// broadcast stream of bounding-box snapshots + a release-mode strip
// guard.
//
// The Flutter overlay widget listens to [changes] and repaints whenever
// the snapshot changes. The MCP bridge (Track 4.4 — spec 035) reads
// [nodes] and [inspect] to answer `GET /xray/tree` and `POST /xray/action`.
//
// Pure-Dart, no Flutter dependency. The release-mode guard is the
// compile-time constant `bool.fromEnvironment('dart.vm.product')` so
// tree-shaking removes the entire class body in release builds when
// the only callers are inside `if (kDebugMode) { ... }` blocks
// (which the codegen emits — see `app_shell_builder.dart`).
//
// Track 4.2 — Spec 036 (issue #181, FR-001, FR-007, FR-008, SC-001, SC-004).
library;

import 'dart:async';

import 'xray_bounding_box.dart';
import 'xray_detail_panel.dart';
import 'xray_node.dart';

/// Compile-time release-mode flag.
///
/// `dart.vm.product` is `true` only when the VM is started with
/// `--dart-define=dart.vm.product=true` (i.e. `flutter build apk --release`
/// or `dart compile exe` with the product define). In a normal `dart test`
/// or `flutter run` it is `false`.
const bool _kReleaseMode = bool.fromEnvironment('dart.vm.product');

/// Mutable registry of X-Ray nodes + a broadcast stream of bounding-box
/// snapshots.
///
/// In release mode, EVERY public method is a no-op:
///   - [activate] does not flip [isActive].
///   - [register] / [unregister] do not modify the registry.
///   - [changes] never emits.
///   - [inspect] always returns `null`.
///
/// This is the second layer of the SC-004 guarantee: even if a stray
/// reference escapes the codegen's `kDebugMode` block, the runtime guard
/// ensures no observable behavior.
class XRayOverlayState {
  /// Singleton — the Flutter app references this via
  /// `XRayOverlayState.instance.activate()` in `main.dart` (emitted by
  /// `app_shell_builder.dart`).
  static final XRayOverlayState instance = XRayOverlayState();

  /// Release-mode flag (overridable in tests via constructor param).
  final bool _isReleaseMode;

  /// Whether the overlay is currently active (toggle via [activate] /
  /// [deactivate]). Stays `false` in release mode.
  bool _isActive = false;

  /// The current registry of nodes keyed by id (insertion-ordered).
  final Map<String, XRayNode> _nodes = {};

  /// Broadcast controller for the [changes] stream.
  final StreamController<List<XRayBoundingBox>> _controller =
      StreamController<List<XRayBoundingBox>>.broadcast();

  XRayOverlayState({bool? isReleaseMode})
    : _isReleaseMode = isReleaseMode ?? _kReleaseMode;

  /// Whether the overlay is currently active.
  bool get isActive => _isActive && !_isReleaseMode;

  /// Snapshot of the current registered nodes (immutable list view).
  List<XRayNode> get nodes =>
      _isReleaseMode ? const [] : List.unmodifiable(_nodes.values);

  /// Broadcast stream of bounding-box snapshots. Emits after every
  /// [register] / [unregister] / state mutation. Emits nothing in
  /// release mode.
  ///
  /// Note: the snapshots contain [XRayBoundingBox] records derived from
  /// each node — but the rect is set to a zero-size placeholder here
  /// because the Flutter overlay is responsible for computing screen
  /// rects from widget RenderBoxes. The pure-Dart layer does not know
  /// screen coordinates.
  Stream<List<XRayBoundingBox>> get changes => _isReleaseMode
      ? const Stream<List<XRayBoundingBox>>.empty()
      : _controller.stream;

  /// Activate the overlay.
  ///
  /// No-op in release mode.
  void activate() {
    if (_isReleaseMode) return;
    _isActive = true;
    _emit();
  }

  /// Deactivate the overlay.
  void deactivate() {
    if (_isReleaseMode) return;
    _isActive = false;
    _emit();
  }

  /// Register a node. If a node with the same id is already registered,
  /// it is replaced. No-op in release mode.
  void register(XRayNode node) {
    if (_isReleaseMode) return;
    _nodes[node.id] = node;
    _emit();
  }

  /// Unregister a node by id. No-op in release mode.
  void unregister(String id) {
    if (_isReleaseMode) return;
    _nodes.remove(id);
    _emit();
  }

  /// Tap-to-inspect: returns a [XRayDetailPanel] with the full state JSON
  /// for the requested node, or `null` if the node is not registered or
  /// the overlay is in release mode.
  XRayDetailPanel? inspect(String nodeId) {
    if (_isReleaseMode) return null;
    final node = _nodes[nodeId];
    if (node == null) return null;
    return XRayDetailPanel.fromNode(node);
  }

  /// Serialize the registry for the MCP bridge (Track 4.4).
  /// In release mode, returns `{"active": false, "nodes": [], "release_mode": true}`.
  Map<String, dynamic> toJson() => {
    'active': isActive,
    'release_mode': _isReleaseMode,
    'nodes': nodes.map((n) => n.toJson()).toList(),
  };

  /// Push the current snapshot to the broadcast stream.
  void _emit() {
    if (_isReleaseMode) return;
    final snapshot = _nodes.values
        .map(
          (n) => XRayBoundingBox.fromNode(
            n,
            rect: const XRayRect(left: 0, top: 0, width: 0, height: 0),
          ),
        )
        .toList();
    _controller.add(snapshot);
  }
}
