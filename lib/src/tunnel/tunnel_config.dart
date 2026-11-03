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
}
