// MCP Server 2.0 — Session persistence across reconnections.
//
// Stores agent session state (subscribed paths, last inspect result,
// pending refactor operations) to a JSON file in .zfa/mcp_sessions/.
//
// SPEC 1136 lane 3: sessions also carry a recorded tool-call sequence
// (`calls`) — the agent-side record of what it invoked during the
// session. `zfa mcp replay <session>` re-executes that sequence against
// the real scaffolded server (deterministic session re-execution).

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// A persisted MCP session.
class McpSession {
  final String id;
  final DateTime createdAt;
  DateTime lastActiveAt;
  final Map<String, dynamic> state;

  /// The recorded tool-call sequence (spec 1136 lane 3): entries of
  /// `{"tool": ..., "arguments": {...}, "expect_contains": ...}` in
  /// call order. `expect_contains` is optional per call. Legacy
  /// sessions without a `calls` key deserialize to an empty sequence.
  /// (Mutable: the recording seam — [McpSessionStore.appendCall] —
  /// extends it.)
  List<Map<String, dynamic>> calls;

  McpSession({
    required this.id,
    required this.createdAt,
    required this.lastActiveAt,
    required this.state,
    List<Map<String, dynamic>>? calls,
  }) : calls = calls ?? <Map<String, dynamic>>[];

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'lastActiveAt': lastActiveAt.toUtc().toIso8601String(),
    'state': state,
    if (calls.isNotEmpty) 'calls': calls,
  };

  factory McpSession.fromJson(Map<String, dynamic> json) {
    return McpSession(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastActiveAt: DateTime.parse(json['lastActiveAt'] as String),
      state: Map<String, dynamic>.from(json['state'] as Map? ?? {}),
      calls: (json['calls'] as List? ?? const [])
          .map((c) => Map<String, dynamic>.from(c as Map))
          .toList(growable: true),
    );
  }
}

/// Manages MCP session persistence.
class McpSessionStore {
  final String projectRoot;
  late final String _sessionsDir;
  final Map<String, McpSession> _cache = {};

  McpSessionStore({required this.projectRoot}) {
    _sessionsDir = p.join(projectRoot, '.zfa', 'mcp_sessions');
  }

  /// Creates or retrieves a session by [id].
  Future<McpSession> getOrCreate(String id) async {
    if (_cache.containsKey(id)) {
      final session = _cache[id]!;
      session.lastActiveAt = DateTime.now().toUtc();
      return session;
    }

    final file = _sessionFile(id);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final session = McpSession.fromJson(
          jsonDecode(content) as Map<String, dynamic>,
        );
        session.lastActiveAt = DateTime.now().toUtc();
        _cache[id] = session;
        return session;
      } catch (_) {
        // Corrupt file — create fresh
      }
    }

    final session = McpSession(
      id: id,
      createdAt: DateTime.now().toUtc(),
      lastActiveAt: DateTime.now().toUtc(),
      state: {},
    );
    _cache[id] = session;
    return session;
  }

  /// Saves a session to disk.
  Future<void> save(McpSession session) async {
    final dir = Directory(_sessionsDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = _sessionFile(session.id);
    await file.writeAsString(jsonEncode(session.toJson()));
  }

  /// Lists all saved session IDs.
  Future<List<String>> listSessions() async {
    final dir = Directory(_sessionsDir);
    if (!await dir.exists()) return [];
    return dir
        .listSync()
        .whereType<File>()
        .map((f) => p.basenameWithoutExtension(f.path))
        .toList();
  }

  /// Deletes a session.
  Future<void> delete(String id) async {
    _cache.remove(id);
    final file = _sessionFile(id);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Appends a recorded tool call to session [id]'s call sequence
  /// and persists it (spec 1136 lane 3): the agent-side recording seam
  /// behind the v2 `session_record` tool. Creates the session when it
  /// does not exist yet.
  Future<void> appendCall(
    String id, {
    required String tool,
    Map<String, dynamic>? arguments,
    String? expectContains,
  }) async {
    final session = await getOrCreate(id);
    final call = <String, dynamic>{
      'tool': tool,
      'arguments': ?arguments,
      'expect_contains': ?expectContains,
    };
    session.calls.add(call);
    await save(session);
  }

  /// The recorded tool-call sequence for session [id] (empty when the
  /// session is unknown or has no calls yet).
  Future<List<Map<String, dynamic>>> callsOf(String id) async {
    final file = _sessionFile(id);
    if (!await file.exists()) return const [];
    try {
      final content = await file.readAsString();
      final session = McpSession.fromJson(
        jsonDecode(content) as Map<String, dynamic>,
      );
      return session.calls;
    } catch (_) {
      // Corrupt session file — nothing recorded is provable.
      return const [];
    }
  }

  File _sessionFile(String id) {
    // Validate session ID to prevent path traversal
    if (id.contains('..') || id.contains('/') || id.contains('\\')) {
      throw ArgumentError(
        'Invalid session ID: must not contain path separators or traversal components',
      );
    }

    final filePath = p.join(_sessionsDir, '$id.json');
    final normalizedPath = p.normalize(filePath);
    final normalizedSessionsDir = p.normalize(_sessionsDir);

    // Ensure the resolved path is still within _sessionsDir
    if (!p.isWithin(normalizedSessionsDir, normalizedPath)) {
      throw ArgumentError(
        'Invalid session ID: resolves outside sessions directory',
      );
    }

    return File(filePath);
  }
}
