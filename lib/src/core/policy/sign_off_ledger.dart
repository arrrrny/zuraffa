import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

class SignOffEntry {
  const SignOffEntry({
    required this.missionId,
    required this.gate,
    required this.requestPayload,
    required this.decision,
    required this.identity,
    required this.timestamp,
    required this.prevHash,
    required this.hash,
  });

  final String missionId;
  final String gate;
  final Map<String, dynamic> requestPayload;
  final String decision;
  final String identity;
  final DateTime timestamp;
  final String prevHash;
  final String hash;

  Map<String, dynamic> toCanonicalJson() => <String, dynamic>{
    'missionId': missionId,
    'gate': gate,
    'requestPayload': _sorted(requestPayload),
    'decision': decision,
    'identity': identity,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'prevHash': prevHash,
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...toCanonicalJson(),
    'hash': hash,
  };

  static SignOffEntry fromJson(Map<String, dynamic> json) {
    return SignOffEntry(
      missionId: json['missionId'] as String,
      gate: json['gate'] as String,
      requestPayload:
          (json['requestPayload'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
      decision: json['decision'] as String,
      identity: json['identity'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      prevHash: json['prevHash'] as String,
      hash: json['hash'] as String,
    );
  }

  static Map<String, dynamic> _sorted(Map<String, dynamic> input) {
    final out = <String, dynamic>{};
    final keys = input.keys.toList()..sort();
    for (final k in keys) {
      final v = input[k];
      if (v is Map<String, dynamic>) {
        out[k] = _sorted(v);
      } else if (v is Map) {
        out[k] = _sorted(v.cast<String, dynamic>());
      } else if (v is List) {
        out[k] = v.map((e) {
          if (e is Map<String, dynamic>) return _sorted(e);
          if (e is Map) return _sorted(e.cast<String, dynamic>());
          return e;
        }).toList();
      } else {
        out[k] = v;
      }
    }
    return out;
  }
}

String computeSignOffHash(SignOffEntry partial) {
  final canonical = jsonEncode(partial.toCanonicalJson());
  return crypto.sha256.convert(utf8.encode(canonical)).toString();
}

class SignOffLedger {
  SignOffLedger({required this.projectRoot})
    : path = p.join(projectRoot, '.zfa', 'ledger', 'signoff.jsonl');

  final String projectRoot;
  final String path;

  File get _file => File(path);

  Future<List<SignOffEntry>> readAll() async {
    if (!_file.existsSync()) return const <SignOffEntry>[];
    final lines = await _file.readAsLines();
    final out = <SignOffEntry>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      out.add(SignOffEntry.fromJson(json));
    }
    return out;
  }

  Future<String> lastHash() async {
    if (!_file.existsSync()) return _genesis;
    final bytes = await _file.readAsBytes();
    if (bytes.isEmpty) return _genesis;
    final text = utf8.decode(bytes, allowMalformed: true);
    final lines = text.split('\n');
    for (var i = lines.length - 1; i >= 0; i--) {
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty) continue;
      try {
        final json = jsonDecode(trimmed) as Map<String, dynamic>;
        final hash = json['hash'];
        if (hash is String && hash.isNotEmpty) return hash;
      } catch (_) {
        // Malformed trailing line: treat as broken chain tail.
      }
      break;
    }
    return _genesis;
  }

  Future<SignOffEntry> append({
    required String missionId,
    required String gate,
    required Map<String, dynamic> requestPayload,
    required String decision,
    required String identity,
    DateTime? timestamp,
  }) async {
    final prev = await lastHash();
    final ts = (timestamp ?? DateTime.now().toUtc());
    final entry = SignOffEntry(
      missionId: missionId,
      gate: gate,
      requestPayload: requestPayload,
      decision: decision,
      identity: identity,
      timestamp: ts,
      prevHash: prev,
      hash: '',
    );
    final hash = computeSignOffHash(entry);
    final persisted = SignOffEntry(
      missionId: missionId,
      gate: gate,
      requestPayload: requestPayload,
      decision: decision,
      identity: identity,
      timestamp: ts,
      prevHash: prev,
      hash: hash,
    );
    final dir = _file.parent;
    if (!dir.existsSync()) dir.createSync(recursive: true);
    await _file.writeAsString(
      '${jsonEncode(persisted.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
    return persisted;
  }

  Future<bool> verify() async {
    List<SignOffEntry> entries;
    try {
      entries = await readAll();
    } catch (_) {
      return false;
    }
    String prev = _genesis;
    for (final e in entries) {
      if (e.prevHash != prev) return false;
      final recomputed = computeSignOffHash(
        SignOffEntry(
          missionId: e.missionId,
          gate: e.gate,
          requestPayload: e.requestPayload,
          decision: e.decision,
          identity: e.identity,
          timestamp: e.timestamp,
          prevHash: e.prevHash,
          hash: '',
        ),
      );
      if (recomputed != e.hash) return false;
      prev = e.hash;
    }
    return true;
  }

  static const String _genesis =
      '0000000000000000000000000000000000000000000000000000000000000000';
}
