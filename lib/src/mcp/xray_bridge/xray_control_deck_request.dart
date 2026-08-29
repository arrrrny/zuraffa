// X-Ray control deck request/response — the JSON shapes for
// `POST /xray/control-deck`.
//
// Track 4.4 — Spec 035 (issue #184, FR-003, FR-008).
library;

import 'xray_bridge_handlers.dart';

/// Request to inject a synthetic mock via the Control Deck.
class XRayControlDeckRequest {
  /// The mock entry name (from `XRayControlDeck.entries`).
  final String mockName;

  const XRayControlDeckRequest({required this.mockName});

  Map<String, dynamic> toJson() => {'mockName': mockName};

  factory XRayControlDeckRequest.fromJson(Map<String, dynamic> json) {
    final m = json['mockName'] as String?;
    if (m == null || m.isEmpty) {
      throw const FormatException(
        'XRayControlDeckRequest: missing required `mockName` field',
      );
    }
    return XRayControlDeckRequest(mockName: m);
  }
}

/// Response from `POST /xray/control-deck`.
///
/// Extends [XRayBridgeResponse] so handlers can return any of the
/// specialized response types polymorphically.
class XRayControlDeckResponse extends XRayBridgeResponse {
  const XRayControlDeckResponse(super.statusCode, super.body);

  /// 200 OK — the mock was injected.
  factory XRayControlDeckResponse.success({
    required String mockName,
    required String injectedPayload,
  }) {
    return XRayControlDeckResponse(200, {
      'success': true,
      'mockName': mockName,
      'injectedPayload': injectedPayload,
    });
  }

  /// 400 Bad Request — request body is malformed.
  factory XRayControlDeckResponse.badRequest(String message) {
    return XRayControlDeckResponse(400, {'success': false, 'error': message});
  }

  /// 404 Not Found — the mockName is unknown; lists available names
  /// per spec FR-008.
  factory XRayControlDeckResponse.unknownMock(
    String requested, {
    required List<String> availableMockNames,
  }) {
    return XRayControlDeckResponse(404, {
      'success': false,
      'error': 'mock "$requested" not registered',
      'availableMockNames': availableMockNames,
    });
  }

  /// 404 Not Found — release-mode strip (FR-006 / SC-004).
  factory XRayControlDeckResponse.releaseMode() {
    return const XRayControlDeckResponse(404, {
      'success': false,
      'error': 'X-Ray endpoints are not available in release builds',
    });
  }
}
