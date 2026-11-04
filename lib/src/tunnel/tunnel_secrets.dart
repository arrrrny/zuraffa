/// Secret redaction for every output surface of the tunnel wrapper
/// (specs/1724-zuraffa-tunnel — issue #2045, FR-003 / SC-005).
///
/// Tokens and credentials-file paths are needed by the real cloudflared
/// process and by nothing else: before a line reaches a log, the state
/// file's human surfaces, or the operator's terminal, every configured
/// secret is replaced with `[redacted]`.
library;

abstract final class TunnelSecrets {
  /// Replaces every non-empty [secrets] occurrence in [text] with
  /// `[redacted]`.
  static String redact(String text, Iterable<String> secrets) {
    var result = text;
    for (final secret in secrets) {
      if (secret.isEmpty) continue;
      result = result.replaceAll(secret, '[redacted]');
    }
    return result;
  }
}
