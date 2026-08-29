// X-Ray bridge auth helpers — localhost check + constant-time bearer
// token validation.
//
// Track 4.4 — Spec 035 (issue #184, FR-005).
library;

/// Pure-Dart auth helpers for the X-Ray bridge.
class XRayBridgeAuth {
  /// Returns `true` if [remoteAddress] is a localhost address.
  ///
  /// Recognized forms:
  ///   - `127.0.0.1`
  ///   - `::1` (IPv6 loopback)
  ///   - `[::1]:port` (IPv6 with port)
  ///   - `127.0.0.1:port` (with port)
  ///   - `localhost`
  static bool isLocalhost(String remoteAddress) {
    if (remoteAddress.isEmpty) return false;
    final lower = remoteAddress.toLowerCase();
    if (lower == 'localhost') return true;
    if (lower.startsWith('127.')) return true;
    if (lower == '::1') return true;
    if (lower.startsWith('[::1]:')) return true;
    if (lower.startsWith('127.0.0.1:')) return true;
    return false;
  }

  /// Validates a received bearer token against the expected one using
  /// a constant-time comparison (no early-exit on first byte mismatch).
  ///
  /// Returns `true` only when both tokens are non-empty AND equal.
  /// Returns `false` when either is `null` or empty (no auth configured
  /// OR no auth provided = rejection).
  static bool validateBearerToken(String? received, String? expected) {
    if (received == null || received.isEmpty) return false;
    if (expected == null || expected.isEmpty) return false;
    return _constantTimeEquals(received, expected);
  }

  /// Same as [validateBearerToken] but accepts the raw HTTP
  /// `Authorization` header value (e.g. `"Bearer abc123"`) and strips
  /// the `Bearer ` prefix if present.
  static bool validateBearerTokenWithHeader(
    String? headerValue,
    String? expected,
  ) {
    if (headerValue == null) return validateBearerToken(null, expected);
    final trimmed = headerValue.trim();
    if (trimmed.toLowerCase().startsWith('bearer ')) {
      return validateBearerToken(trimmed.substring(7).trim(), expected);
    }
    return validateBearerToken(trimmed, expected);
  }

  /// Constant-time string comparison. Compares all bytes regardless of
  /// early mismatches so timing side-channels cannot reveal the prefix.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) {
      // Length comparison itself is a side-channel, but the spec doesn't
      // require length-equality to be hidden — only the prefix. We still
      // scan both strings fully (over their common length) to flatten
      // timing further.
      final minLen = a.length < b.length ? a.length : b.length;
      for (var i = 0; i < minLen; i++) {
        // Intentionally compare and discard the result; the loop's purpose
        // is to consume time, not to compute a value here.
        // ignore: statement_without_result
        a[i] == b[i];
      }
      return false; // Length mismatch always returns false.
    }
    var match = true;
    for (var i = 0; i < a.length; i++) {
      match &= (a[i] == b[i]);
    }
    return match;
  }
}
