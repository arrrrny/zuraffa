/// Whitelisted network lanes for the simulation-mode isolation guard
/// (spec 893, T004; FR-006).
///
/// A lane is an explicitly approved network path that may bypass the
/// isolation guard in simulation mode (e.g. analytics, crash reporting).
/// Lanes come from a project-level configuration file (`.zfa.json` →
/// `simulation.whitelist`). An empty whitelist is the safest default:
/// every socket is blocked.
library;

import 'dart:convert';
import 'dart:io';

/// One explicitly approved network lane.
final class SocketLane {
  const SocketLane({required this.host, this.port});

  /// The lane host. A leading dot (`.example.com`) approves the whole
  /// subdomain tree including the apex domain.
  final String host;

  /// Optional port constraint; `null` approves every port on [host].
  final int? port;

  /// Whether a connection attempt to [candidateHost]:[candidatePort] is
  /// approved by this lane.
  bool matches(String candidateHost, int candidatePort) {
    if (port != null && port != candidatePort) return false;
    if (host.startsWith('.')) {
      final apex = host.substring(1);
      return candidateHost == apex || candidateHost.endsWith(host);
    }
    return candidateHost == host;
  }

  /// Parses a lane from config data: a plain host string, or a map with
  /// `host` / optional `port` keys.
  static SocketLane parse(Object? data) {
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) {
        throw ArgumentError.value(data, 'data', 'lane host must not be empty');
      }
      return SocketLane(host: trimmed);
    }
    if (data is Map) {
      final host = data['host'];
      if (host is! String || host.trim().isEmpty) {
        throw ArgumentError.value(data, 'data', 'lane requires a host string');
      }
      final port = data['port'];
      if (port != null && port is! int) {
        throw ArgumentError.value(data, 'data', 'lane port must be an int');
      }
      return SocketLane(host: host.trim(), port: port);
    }
    throw ArgumentError.value(data, 'data', 'unsupported lane definition');
  }

  @override
  String toString() => port == null ? 'SocketLane($host)' : 'SocketLane($host:$port)';
}

/// Loads the isolation-guard whitelist from the project-level
/// configuration file (`.zfa.json` → `simulation.whitelist`).
final class SimulationWhitelistConfig {
  SimulationWhitelistConfig._();

  /// Reads [path] and parses `simulation.whitelist`. A missing file or a
  /// missing key yields the empty (safe) whitelist. Malformed entries
  /// throw [FormatException] — a lane that cannot be parsed must never
  /// silently open network access.
  static List<SocketLane> load(String path) {
    final file = File(path);
    if (!file.existsSync()) return const [];
    Map<String, dynamic> doc;
    try {
      doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } on FormatException {
      rethrow;
    } on TypeError {
      throw const FormatException('project config is not a JSON object');
    }
    final simulation = doc['simulation'];
    if (simulation is! Map<String, dynamic>) return const [];
    final whitelist = simulation['whitelist'];
    if (whitelist is! List) return const [];
    return whitelist.map(_parseEntry).toList();
  }

  static SocketLane _parseEntry(Object? entry) {
    // Shorthand single-lane map: {".crashlytics.com": 443}. The key is
    // the host, so the reserved key names are excluded from shorthand
    // interpretation and fall through to strict parsing.
    if (entry is Map &&
        entry.length == 1 &&
        !entry.containsKey('host') &&
        !entry.containsKey('port')) {
      final host = entry.keys.first;
      final port = entry.values.first;
      if (host is String && host.trim().isNotEmpty && port is int) {
        return SocketLane(host: host.trim(), port: port);
      }
    }
    try {
      return SocketLane.parse(entry);
    } on ArgumentError catch (e) {
      throw FormatException('invalid simulation whitelist lane: $e');
    }
  }
}
