// X-Ray bridge handlers — pure-Dart request handlers for
// `GET /xray/tree`, `POST /xray/action`, `POST /xray/control-deck`.
//
// The Flutter `XRayBridgeServer` (in `zuraffa_flutter`) delegates HTTP
// requests to these handlers. Each handler returns an [XRayBridgeResponse]
// (status code + canonical JSON body).
//
// The handlers accept the overlay state + control deck as `dynamic`
// constructor params (the registries defined in spec 036 / 034) to avoid
// forward dependencies on those PRs. The handlers use dynamic dispatch
// (calling `registry.toJson()`, `deck.inject(name)`, etc.) which is
// duck-typed — any object exposing the right methods will work.
//
// In release mode, every handler returns 404 (FR-006 / SC-004).
//
// Track 4.4 — Spec 035 (issue #184, FR-001..008, SC-001..004).
library;

import '../../core/xray_config.dart';
import 'xray_action_request.dart';
import 'xray_control_deck_request.dart';

/// A handler response: HTTP status code + canonical JSON body.
///
/// Subclasses ([XRayActionResponse], [XRayControlDeckResponse]) extend
/// this class so the handlers can return any of the specialized
/// response types while the HTTP layer treats them polymorphically.
class XRayBridgeResponse {
  final int statusCode;
  final Map<String, dynamic> body;

  const XRayBridgeResponse(this.statusCode, this.body);
}

/// Pure-Dart handlers for the X-Ray bridge HTTP endpoints.
class XRayBridgeHandlers {
  /// The overlay state registry (spec 036 — `XRayOverlayState`).
  /// Duck-typed: must expose `toJson()` returning a map containing
  /// the keys `activeView` (String? or null) and `nodes`
  /// (List of Map).
  final dynamic overlayState;

  /// The control deck registry (spec 034 — `XRayControlDeck`).
  /// Duck-typed: must expose `mockNames` (a List of String) and
  /// `inject(name)` returning the payload string or null.
  final dynamic controlDeck;

  final bool _isReleaseMode;

  XRayBridgeHandlers({
    required this.overlayState,
    required this.controlDeck,
    bool? isReleaseMode,
  }) : _isReleaseMode = isReleaseMode ?? kXrayReleaseMode;

  /// `GET /xray/tree` — returns the current X-Ray tree as JSON.
  ///
  /// Release mode: 404 (FR-006 / SC-004).
  XRayBridgeResponse handleTreeGet() {
    if (_isReleaseMode) {
      return const XRayBridgeResponse(404, {
        'success': false,
        'error': 'X-Ray endpoints are not available in release builds',
      });
    }

    // Duck-typed: overlayState.toJson() returns the canonical shape.
    final dynamic overlayJson = overlayState.toJson();
    final Map<String, dynamic> body = Map<String, dynamic>.from(overlayJson);

    // Always 200 — even an empty tree is a valid response (spec FR-001).
    return XRayBridgeResponse(200, {
      'success': true,
      'activeView': body['activeView'],
      'nodes': body['nodes'] ?? const <Map<String, dynamic>>[],
    });
  }

  /// `POST /xray/action` — triggers a node's bound action.
  XRayBridgeResponse handleActionPost(Map<String, dynamic> body) {
    if (_isReleaseMode) {
      return XRayActionResponse.releaseMode();
    }

    // Parse + validate the request body.
    XRayActionRequest req;
    try {
      req = XRayActionRequest.fromJson(body);
    } on FormatException catch (e) {
      return XRayActionResponse.badRequest(e.message);
    }

    // Find the target node in the overlay.
    final overlayJson = overlayState.toJson() as Map<String, dynamic>;
    final nodesList =
        (overlayJson['nodes'] as List<dynamic>?) ?? const <dynamic>[];
    Map<String, dynamic>? target;
    final availableIds = <String>[];
    for (final n in nodesList) {
      // A malformed node (null / scalar / nested list) must not crash the
      // handler — skip it like we skip nodes without an id.
      if (n is! Map<String, dynamic>) continue;
      final node = n;
      final id = node['id']?.toString();
      if (id == null) continue;
      availableIds.add(id);
      if (id == req.targetNode) {
        target = node;
      }
    }

    if (target == null) {
      return XRayActionResponse.unknownNode(
        req.targetNode,
        availableNodeIds: availableIds,
      );
    }

    final boundAction = target['boundAction'];
    if (boundAction == null || boundAction.toString().isEmpty) {
      return XRayActionResponse.noBoundAction(req.targetNode);
    }

    // Invoke the bound action via the overlay's `inspect(id)` API which
    // returns the action's result (or null). The Flutter side wires
    // `inspect` to actually call the action callback; the pure-Dart side
    // just relays the result.
    final dynamic inspectResult = overlayState.inspect(req.targetNode);
    final Map<String, dynamic> actionResult = inspectResult == null
        ? <String, dynamic>{'invoked': true}
        : Map<String, dynamic>.from(inspectResult as Map);

    return XRayActionResponse.success(
      nodeId: req.targetNode,
      actionResult: actionResult,
    );
  }

  /// `POST /xray/control-deck` — injects a synthetic mock.
  XRayBridgeResponse handleControlDeckPost(Map<String, dynamic> body) {
    if (_isReleaseMode) {
      return XRayControlDeckResponse.releaseMode();
    }

    XRayControlDeckRequest req;
    try {
      req = XRayControlDeckRequest.fromJson(body);
    } on FormatException catch (e) {
      return XRayControlDeckResponse.badRequest(e.message);
    }

    final dynamic injected = controlDeck.inject(req.mockName);
    if (injected == null) {
      // Build the name list only for the error path. `controlDeck` is
      // duck-typed (spec 034), so guard against a null / non-iterable
      // `mockNames` instead of casting unchecked.
      final dynamic mockNames = controlDeck.mockNames;
      final availableNames = mockNames is Iterable
          ? List<String>.from(mockNames)
          : <String>[];
      return XRayControlDeckResponse.unknownMock(
        req.mockName,
        availableMockNames: availableNames,
      );
    }

    return XRayControlDeckResponse.success(
      mockName: req.mockName,
      injectedPayload: injected.toString(),
    );
  }
}
