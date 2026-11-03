/// The persisted tunnel state (specs/1724-zuraffa-tunnel - issue #2045,
/// FR-007).
///
/// Lives under the project's `.zfa/` memory (`.zfa/tunnel/state.json`) so
/// any later invocation - `zfa tunnel status`, a restart of the wrapper, an
/// operator shell - can resurface the current URL without the tunnel
/// process still being attached to it. Quick-tunnel URLs CHANGE on every
/// restart; the record always carries the latest one (named mode is the
/// durable answer, documented in docs/tunnel.md).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class TunnelStateRecord {
  const TunnelStateRecord({
    required this.mode,
    required this.port,
    this.url,
    this.pid,
    this.restarts = 0,
    required this.startedAt,
    this.lastRestartAt,
    this.failureReason,
    this.running = false,
  });

  final String mode;
  final int port;
  final String? url;
  final int? pid;
  final int restarts;
  final DateTime startedAt;
  final DateTime? lastRestartAt;
  final String? failureReason;
  final bool running;

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'port': port,
    'url': url,
    'pid': pid,
    'restarts': restarts,
    'startedAt': startedAt.toIso8601String(),
    'lastRestartAt': lastRestartAt?.toIso8601String(),
    'failureReason': failureReason,
    'running': running,
  };

  factory TunnelStateRecord.fromJson(Map<String, dynamic> json) {
    return TunnelStateRecord(
      mode: json['mode'] as String? ?? 'quick',
      port: json['port'] as int? ?? 0,
      url: json['url'] as String?,
      pid: json['pid'] as int?,
      restarts: json['restarts'] as int? ?? 0,
      startedAt:
          DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lastRestartAt: json['lastRestartAt'] == null
          ? null
          : DateTime.tryParse(json['lastRestartAt'] as String),
      failureReason: json['failureReason'] as String?,
      running: json['running'] as bool? ?? false,
    );
  }
}

class TunnelState {
  TunnelState({String? projectRoot})
    : _projectRoot = projectRoot ?? Directory.current.path;

  final String _projectRoot;

  String get stateFilePath =>
      p.join(_projectRoot, '.zfa', 'tunnel', 'state.json');

  Future<void> save(TunnelStateRecord record) async {
    final file = File(stateFilePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(record.toJson()),
    );
  }

  /// The last saved record, or `null` when nothing (usable) was saved.
  TunnelStateRecord? read() {
    final file = File(stateFilePath);
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) return null;
      return TunnelStateRecord.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }
}
