/// `NetworkIsolationGuard` — the TDD certification that simulated worlds
/// never open a real socket (bug #832, VISION §9).
///
/// ## Why
///
/// Hosted TDD tests exercise external-service data sources through
/// certified simulation adapters (see `simulation_adapters.dart`). The
/// only way to *prove* the simulation is to fail — loudly and before any
/// packet leaves the process — if a test under the guard attempts a real
/// outbound socket.
///
/// ## Soundness (no false positives)
///
/// The guard intercepts exactly two hooks:
///
/// 1. `IOOverrides.global.socketConnect` / `socketStartConnect` — every
///    `Socket.connect` / `Socket.startConnect` (raw and, via the raw
///    layer, secure) routes through these.
/// 2. `HttpOverrides.global.createHttpClient` — every `HttpClient()`
///    created while the guard is active gets a `connectionFactory` that
///    refuses to dial.
///
/// Nothing else is touched: file I/O, isolates, timers, and pure compute
/// keep working, so plain-Dart TDD tests that never open a socket are
/// unaffected. Intercepted attempts throw *before* any DNS lookup or
/// dial happens — a blocked test never touches the network.
///
/// ## Usage (test bootstrap)
///
/// ```dart
/// void main() {
///   setUpAll(NetworkIsolationGuard.install);
///   tearDownAll(NetworkIsolationGuard.uninstall);
///   // ...
/// }
/// ```
///
/// `SimulationWorld.boot` installs the guard automatically so every
/// simulation-driven TDD test is certified by default.
library;

import 'dart:io';

/// Thrown when code running under [NetworkIsolationGuard] attempts to
/// open a real socket. Extends [Error] (not [Exception]) so `catch (e)`
/// blocks that are not explicitly isolating network access do not
/// silently swallow the certification failure.
final class NetworkIsolationViolation extends Error {
  NetworkIsolationViolation(this.operation, this.host, this.port);

  /// The blocked operation, e.g. `Socket.connect` or `HttpClient.connect`.
  final String operation;

  /// The host the code tried to reach.
  final String host;

  /// The port the code tried to reach.
  final int port;

  @override
  String toString() =>
      'NetworkIsolationViolation: $operation to $host:$port was blocked. '
      'This test runs under the network-isolation guard (bug #832): '
      'external services must be consumed through certified simulation '
      'adapters (package:zuraffa/src/simulation), never through real '
      'sockets.';
}

/// Installs/restores the outbound-socket interception. Idempotent and
/// re-installable; [uninstall] restores the overrides that were active
/// before [install].
final class NetworkIsolationGuard {
  NetworkIsolationGuard._();

  static bool _active = false;
  static IOOverrides? _savedIO;
  static HttpOverrides? _savedHttp;

  /// Whether the guard currently intercepts outbound sockets.
  static bool get isActive => _active;

  /// Begin failing every outbound socket attempt with
  /// [NetworkIsolationViolation]. Calling [install] while already active
  /// is a no-op, so test `setUpAll` hooks can call it unconditionally.
  static void install() {
    if (_active) return;
    _savedIO = IOOverrides.current;
    _savedHttp = HttpOverrides.current;
    IOOverrides.global = _GuardedIOOverrides();
    HttpOverrides.global = _GuardedHttpOverrides();
    _active = true;
  }

  /// Restore the pre-[install] overrides. Safe to call when the guard is
  /// not active (and when it was never installed).
  static void uninstall() {
    if (!_active) return;
    IOOverrides.global = _savedIO;
    HttpOverrides.global = _savedHttp;
    _savedIO = null;
    _savedHttp = null;
    _active = false;
  }
}

/// Refuses every outbound socket before any dial or DNS lookup happens.
final class _GuardedIOOverrides extends IOOverrides {
  @override
  Future<Socket> socketConnect(
    host,
    int port, {
    sourceAddress,
    int sourcePort = 0,
    Duration? timeout,
  }) async => throw NetworkIsolationViolation('Socket.connect', '$host', port);

  @override
  Future<ConnectionTask<Socket>> socketStartConnect(
    host,
    int port, {
    sourceAddress,
    int sourcePort = 0,
  }) async =>
      throw NetworkIsolationViolation('Socket.startConnect', '$host', port);
}

/// Hands out [HttpClient]s whose connection factory refuses to dial.
final class _GuardedHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    // Build the raw client via super — `new HttpClient()` would consult
    // HttpOverrides.current again and recurse until the stack overflows.
    final client = super.createHttpClient(context)
      ..connectionFactory =
          (Uri uri, String? proxyHost, int? proxyPort) async =>
              throw NetworkIsolationViolation(
                'HttpClient.connect',
                proxyHost ?? uri.host,
                proxyPort ?? uri.port,
              );
    return client;
  }
}
