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

import 'simulation_whitelist.dart';

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
  static List<SocketLane> _lanes = const [];

  /// Approved-exception log (FR-006/US3 scenario 2): every connect that
  /// matched a whitelisted lane is recorded here. Bounded to the most
  /// recent [_maxApprovedAttempts] attempts so long demo sessions cannot
  /// grow it without limit.
  static final List<({String host, int port, String operation})>
  _approved = [];

  static const int _maxApprovedAttempts = 500;

  /// Whether the guard currently intercepts outbound sockets.
  static bool get isActive => _active;

  /// The approved connections recorded since [install] (unmodifiable).
  static List<({String host, int port, String operation})>
  get approvedAttempts => List.unmodifiable(_approved);

  /// Begin failing every non-whitelisted outbound socket attempt with
  /// [NetworkIsolationViolation]. [whitelist] lanes (FR-006) are
  /// permitted and logged as approved exceptions; the empty whitelist —
  /// the default — blocks every socket (safest default, unchanged #832
  /// behavior). Calling [install] while already active is a no-op, so
  /// test `setUpAll` hooks can call it unconditionally.
  static void install({List<SocketLane> whitelist = const []}) {
    if (_active) return;
    _lanes = List.of(whitelist);
    _approved.clear();
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
    _lanes = const [];
    _approved.clear();
    _active = false;
  }

  /// FR-007: whitelisted lanes are permitted (and recorded as approved
  /// exceptions); every other attempt is blocked with a diagnostic
  /// identifying the source.
  static bool _isAllowed(String host, int port, String operation) {
    for (final lane in _lanes) {
      if (lane.matches(host, port)) {
        if (_approved.length < _maxApprovedAttempts) {
          _approved.add((host: host, port: port, operation: operation));
        }
        return true;
      }
    }
    return false;
  }

  /// A pristine overrides instance whose inherited default methods ARE
  /// the raw socket path — used when no overrides were installed before
  /// the guard, so whitelisted lanes always reach real dialing.
  static final IOOverrides _rawIO = _PassthroughIOOverrides();

  /// Delegates a whitelisted connect to the socket path that was active
  /// before [install]: the saved overrides object when one existed,
  /// otherwise the raw default hooks.
  static Future<Socket> _delegateSocketConnect(
    dynamic host,
    int port, {
    dynamic sourceAddress,
    int sourcePort = 0,
    Duration? timeout,
  }) {
    return (_savedIO ?? _rawIO).socketConnect(
      host,
      port,
      sourceAddress: sourceAddress,
      sourcePort: sourcePort,
      timeout: timeout,
    );
  }

  static Future<ConnectionTask<Socket>> _delegateSocketStartConnect(
    dynamic host,
    int port, {
    dynamic sourceAddress,
    int sourcePort = 0,
  }) {
    return (_savedIO ?? _rawIO).socketStartConnect(
      host,
      port,
      sourceAddress: sourceAddress,
      sourcePort: sourcePort,
    );
  }
}

/// Concrete pass-through overrides: overriding nothing, every hook keeps
/// its raw dart:io default implementation.
final class _PassthroughIOOverrides extends IOOverrides {}

/// Refuses every non-whitelisted outbound socket before any dial or DNS
/// lookup happens; whitelisted lanes (spec 893) delegate to the real
/// socket path with the guard's overrides temporarily lifted.
final class _GuardedIOOverrides extends IOOverrides {
  @override
  Future<Socket> socketConnect(
    host,
    int port, {
    sourceAddress,
    int sourcePort = 0,
    Duration? timeout,
  }) async {
    final hostString = '$host';
    if (NetworkIsolationGuard._isAllowed(hostString, port, 'Socket.connect')) {
      return NetworkIsolationGuard._delegateSocketConnect(
        host,
        port,
        sourceAddress: sourceAddress,
        sourcePort: sourcePort,
        timeout: timeout,
      );
    }
    throw NetworkIsolationViolation('Socket.connect', hostString, port);
  }

  @override
  Future<ConnectionTask<Socket>> socketStartConnect(
    host,
    int port, {
    sourceAddress,
    int sourcePort = 0,
  }) async {
    final hostString = '$host';
    if (NetworkIsolationGuard._isAllowed(
      hostString,
      port,
      'Socket.startConnect',
    )) {
      return NetworkIsolationGuard._delegateSocketStartConnect(
        host,
        port,
        sourceAddress: sourceAddress,
        sourcePort: sourcePort,
      );
    }
    throw NetworkIsolationViolation('Socket.startConnect', hostString, port);
  }
}

/// Hands out [HttpClient]s whose connection factory refuses to dial
/// unless the request targets a whitelisted lane.
final class _GuardedHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    // Build the raw client via super — `new HttpClient()` would consult
    // HttpOverrides.current again and recurse until the stack overflows.
    final client = super.createHttpClient(context)
      ..connectionFactory = (
        Uri uri,
        String? proxyHost,
        int? proxyPort,
      ) async {
        final host = proxyHost ?? uri.host;
        final port = proxyPort ?? uri.port;
        if (NetworkIsolationGuard._isAllowed(
          host,
          port,
          'HttpClient.connect',
        )) {
          // Whitelisted lane: dial through the real socket path with the
          // guard's overrides lifted (the IO-level lane check re-approves
          // and records the attempt).
          return NetworkIsolationGuard._delegateSocketStartConnect(
            host,
            port,
          );
        }
        throw NetworkIsolationViolation('HttpClient.connect', host, port);
      };
    return client;
  }
}
