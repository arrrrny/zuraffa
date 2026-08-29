// X-Ray action request/response — the JSON shapes for `POST /xray/action`.
//
// Track 4.4 — Spec 035 (issue #184, FR-002, FR-007).
library;

import 'xray_bridge_handlers.dart';

/// Request to trigger a node's bound action via the MCP bridge.
class XRayActionRequest {
  /// The id of the target XRayNode (from `GET /xray/tree`).
  final String targetNode;

  /// Optional payload forwarded to the bound action.
  final Map<String, dynamic>? payload;

  const XRayActionRequest({required this.targetNode, this.payload});

  Map<String, dynamic> toJson() {
    final j = <String, dynamic>{'targetNode': targetNode};
    if (payload != null) j['payload'] = payload;
    return j;
  }

  factory XRayActionRequest.fromJson(Map<String, dynamic> json) {
    final t = json['targetNode'] as String?;
    if (t == null || t.isEmpty) {
      throw const FormatException(
        'XRayActionRequest: missing required `targetNode` field',
      );
    }
    return XRayActionRequest(
      targetNode: t,
      payload: json['payload'] as Map<String, dynamic>?,
    );
  }
}

/// Response from `POST /xray/action`.
///
/// Extends [XRayBridgeResponse] so handlers can return any of the
/// specialized response types polymorphically.
class XRayActionResponse extends XRayBridgeResponse {
  const XRayActionResponse(super.statusCode, super.body);

  /// 200 OK — the bound action was invoked successfully.
  factory XRayActionResponse.success({
    required String nodeId,
    required Map<String, dynamic> actionResult,
  }) {
    return XRayActionResponse(200, {
      'success': true,
      'nodeId': nodeId,
      'actionResult': actionResult,
    });
  }

  /// 400 Bad Request — the node exists but has no bound action.
  factory XRayActionResponse.noBoundAction(String nodeId) {
    return XRayActionResponse(400, {
      'success': false,
      'nodeId': nodeId,
      'error': 'node $nodeId has no bound action',
    });
  }

  /// 400 Bad Request — the request body is malformed.
  factory XRayActionResponse.badRequest(String message) {
    return XRayActionResponse(400, {
      'success': false,
      'error': message,
    });
  }

  /// 404 Not Found — the targetNode is unknown; lists available ids
  /// per spec FR-007.
  factory XRayActionResponse.unknownNode(
    String requested, {
    required List<String> availableNodeIds,
  }) {
    return XRayActionResponse(404, {
      'success': false,
      'error': 'node "$requested" not found in current tree',
      'availableNodeIds': availableNodeIds,
    });
  }

  /// 404 Not Found — release-mode strip (FR-006 / SC-004).
  factory XRayActionResponse.releaseMode() {
    return const XRayActionResponse(404, {
      'success': false,
      'error': 'X-Ray endpoints are not available in release builds',
    });
  }
}
