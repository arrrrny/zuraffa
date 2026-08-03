// MCP Server 2.0 — Token-based authentication for remote agents.
//
// - localhost (127.0.0.1 / ::1): no auth required
// - remote connections: Bearer token in Authorization header or
//   "auth" field in the JSON-RPC request body


import 'dart:io';
import 'dart:math';

/// Token-based authentication for the MCP server.
class McpAuth {
  final String? token;
  final List<String> _nonLocalAllowedIps;

  /// Creates an [McpAuth] instance.
  ///
  /// [token] — if null, all connections are allowed (dev mode).
  /// [nonLocalAllowedIps] — IPs that bypass auth even when a token is set.
  McpAuth({this.token, List<String>? nonLocalAllowedIps})
      : _nonLocalAllowedIps = nonLocalAllowedIps ?? const [];

  /// Whether authentication is enabled (i.e. a token is configured).
  bool get isEnabled => token != null && token!.isNotEmpty;

  /// Validates an incoming connection.
  ///
  /// Returns `null` on success, or an error message on failure.
  String? validateConnection(Socket socket) {
    if (!isEnabled) return null;
    if (_isLocalhost(socket.remoteAddress)) return null;
    // No token was provided at the transport level (WebSocket upgrade),
    // so auth must happen per-message via the "auth" field.
    return null; // Defer to per-message auth
  }

  /// Validates a per-message auth.
  ///
  /// Checks the "auth" field in the JSON-RPC request body.
  String? validateMessage(Map<String, dynamic> request, String? remoteIp) {
    if (!isEnabled) return null;
    if (_isLocalhostIp(remoteIp)) return null;
    if (_nonLocalAllowedIps.contains(remoteIp)) return null;

    final auth = request['auth'];
    if (auth == null) {
      return 'Authentication required: include "auth" field with bearer token';
    }
    if (auth is! String || !_constantTimeEquals(auth, token ?? '')) {
      return 'Authentication failed: invalid token';
    }
    return null;
  }

  /// Validates an Authorization header value ("Bearer <token>").
  bool validateHeader(String? authHeader) {
    if (!isEnabled) return true;
    if (authHeader == null) return false;

    // Parse scheme case-insensitively
    final parts = authHeader.split(' ');
    if (parts.length != 2) return false;
    if (parts[0].toLowerCase() != 'bearer') return false;

    return _constantTimeEquals(parts[1], token ?? '');
  }

  bool _isLocalhost(InternetAddress addr) {
    return addr.isLoopback;
  }

  bool _isLocalhostIp(String? ip) {
    if (ip == null) return false;
    // Reject the string "localhost" as it's spoofable
    if (ip == 'localhost') return false;

    try {
      final addr = InternetAddress(ip);
      return addr.isLoopback;
    } catch (_) {
      return false;
    }
  }

  /// Constant-time string comparison to prevent timing attacks.
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Generates a random hex token.
  static String generateToken({int length = 32}) {
    final random = Random.secure();
    return List.generate(length, (_) => random.nextInt(16).toRadixString(16))
        .join();
  }
}
