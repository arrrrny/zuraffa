/// The declared, single-port tunnel the operator asked for
/// (specs/1724-zuraffa-tunnel — issue #2045).
///
/// FR-009: the scope is ALWAYS exactly one local port on a loopback host —
/// there is no implicit default port and no wildcard/whole-host scope. The
/// [validationErrors] contract is what `zfa tunnel run` refuses on (exit
/// 2, usage).
library;

/// How the tunnel is driven.
enum TunnelMode {
  /// Zero-config ephemeral quick tunnel (trycloudflare.com URL).
  quick,

  /// User-defined DNS: locally-managed named tunnel with a credentials file.
  named,

  /// Remotely-managed named tunnel driven by a Cloudflare-issued token.
  token,
}

class TunnelConfig {
  const TunnelConfig({
    required this.mode,
    required this.port,
    this.host = 'localhost',
    this.tunnelName,
    this.hostname,
    this.credentialsFile,
    this.token,
    this.allowUnauthenticated = false,
  });

  final TunnelMode mode;

  /// The ONLY local port exposed through the tunnel.
  final int port;

  /// Loopback origin host (never a wildcard bind).
  final String host;
  final String? tunnelName;
  final String? hostname;
  final String? credentialsFile;
  final String? token;

  /// The explicit operator override for the unauthenticated-endpoint guard
  /// (FR-004): `--i-know-its-unauthenticated`.
  final bool allowUnauthenticated;

  /// The loopback origin the tunnel forwards to.
  Uri get target => Uri(scheme: 'http', host: host, port: port);

  /// Human-readable refusal reasons; empty when the config is runnable.
  List<String> validationErrors() {
    final errors = <String>[];
    if (port < 1 || port > 65535) {
      errors.add('--port must be between 1 and 65535 (got $port)');
    }
    // FR-009: the origin is loopback-only. `--host 10.0.0.5` (or 0.0.0.0)
    // would point cloudflared at a non-loopback service the tunnel then
    // publishes — validated here, not left to the help text.
    if (!_isLoopbackHost(host)) {
      errors.add(
        '--host must be a loopback host (localhost, 127.0.0.1, ::1) — '
        'the tunnel scope is always one local port; got "$host"',
      );
    }
    switch (mode) {
      case TunnelMode.quick:
        break;
      case TunnelMode.named:
        if (tunnelName == null || tunnelName!.isEmpty) {
          errors.add('--tunnel-name is required in named mode');
        }
        if (hostname == null || hostname!.isEmpty) {
          errors.add('--hostname is required in named mode');
        }
        if (credentialsFile == null || credentialsFile!.isEmpty) {
          errors.add('--credentials-file is required in named mode');
        }
      case TunnelMode.token:
        if (token == null || token!.isEmpty) {
          errors.add('--token is required in token mode');
        }
    }
    return errors;
  }

  bool get isValid => validationErrors().isEmpty;

  /// FR-009: the origin host is loopback-only — `localhost`, the 127/8
  /// loopback range, or IPv6 `::1` with or without brackets.
  static bool _isLoopbackHost(String host) {
    final normalized = host.toLowerCase();
    if (normalized == 'localhost' || normalized == '::1') {
      return true;
    }
    if (normalized.startsWith('[') && normalized.endsWith(']')) {
      return _isLoopbackHost(normalized.substring(1, normalized.length - 1));
    }
    if (normalized.startsWith('127.')) {
      final octets = normalized.split('.');
      return octets.length == 4 &&
          octets.skip(1).every((o) {
            final value = int.tryParse(o);
            return value != null && value >= 0 && value <= 255;
          });
    }
    return false;
  }
}
