/// Mission document format for the agent shell (issue #808).
///
/// "Mission document format (kernel already tests this) + resume-from-
/// snapshot" — the kernel's `Mission`/`AgentState` already prove the
/// coalescing key + session-state JSON; this document adds what a
/// long-lived shell needs: **role**, **goal**, **steps with durable
/// status**, **cursor**, **held lease scopes** and a **budget spec**, all
/// serializable so a fresh agent (or a fresh daemon process) resumes
/// exactly where the last one died.
library;

import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

/// Role missions: planner, builder, reviewer, operator — same kernel,
/// different tool gates (issue #808).
enum AgentRole { planner, builder, reviewer, operator }

/// Status of a single mission step.
enum MissionStepStatus { pending, running, done, skipped }

/// Status of the whole mission document.
enum MissionDocumentStatus { pending, running, completed, failed, cancelled }

/// Budget spec carried inside the document (mirrors the policy shell's
/// `MissionBudget` dimensions that the v0 slice meters: calls + tokens).
@immutable
class MissionBudgetSpec {
  const MissionBudgetSpec({this.maxCalls, this.maxTokens});

  final int? maxCalls;
  final int? maxTokens;

  Map<String, Object?> toJson() => <String, Object?>{
    'maxCalls': maxCalls,
    'maxTokens': maxTokens,
  };

  static MissionBudgetSpec fromJson(Map<String, Object?> json) =>
      MissionBudgetSpec(
        maxCalls: json['maxCalls'] as int?,
        maxTokens: json['maxTokens'] as int?,
      );
}

/// One step of a mission.
@immutable
class MissionStep {
  const MissionStep({
    required this.id,
    required this.description,
    this.status = MissionStepStatus.pending,
  });

  final String id;
  final String description;
  final MissionStepStatus status;

  MissionStep withStatus(MissionStepStatus status) =>
      MissionStep(id: id, description: description, status: status);

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'description': description,
    'status': status.name,
  };

  static MissionStep fromJson(Map<String, Object?> json) => MissionStep(
    id: json['id'] as String,
    description: json['description'] as String,
    status: _stepStatus(json['status'] as String?),
  );

  static MissionStepStatus _stepStatus(String? name) =>
      MissionStepStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => MissionStepStatus.pending,
      );
}

/// Tool gates per role (issue #808: "same kernel, different tool gates").
///
/// These compose with the policy shell's `PermissionRegistry`: the
/// registry decides HOW RISKY a tool is, the role gate decides WHETHER the
/// role may touch it at all.
abstract final class RoleGates {
  static const Map<AgentRole, Set<String>> _gates = <AgentRole, Set<String>>{
    // Plans the work; reads code and tests; never mutates code.
    AgentRole.planner: <String>{
      'plan.read',
      'plan.write',
      'code.read',
      'test.run',
    },
    // Implements; the only role allowed to write code — and even that only
    // through a lease-guarded write.
    AgentRole.builder: <String>{
      'plan.read',
      'code.read',
      'code.write',
      'test.run',
    },
    // Reviews; may approve/reject but never write or deploy.
    AgentRole.reviewer: <String>{
      'plan.read',
      'code.read',
      'review.approve',
      'review.reject',
    },
    // Operates; deploy/rollback but never mutates the codebase.
    AgentRole.operator: <String>{'deploy.run', 'rollback.run', 'status.read'},
  };

  /// The gate set for [role] (never mutated by callers).
  static Set<String> forRole(AgentRole role) => _gates[role]!;

  /// Whether [role] may use [tool].
  static bool allows(AgentRole role, String tool) =>
      _gates[role]!.contains(tool);
}

/// The durable mission document.
@immutable
class MissionDocument {
  const MissionDocument({
    required this.missionId,
    required this.role,
    required this.goal,
    required this.feature,
    this.steps = const <MissionStep>[],
    this.cursor = 0,
    this.status = MissionDocumentStatus.pending,
    this.heldScopes = const <String>[],
    this.budget,
    this.updatedAt,
  });

  final String missionId;
  final AgentRole role;
  final String goal;

  /// Workspace scope this mission operates on (a feature directory).
  final String feature;
  final List<MissionStep> steps;

  /// Index of the next step to execute (resume point).
  final int cursor;
  final MissionDocumentStatus status;

  /// Lease scopes the mission currently holds.
  final List<String> heldScopes;
  final MissionBudgetSpec? budget;

  /// Last durability timestamp (set by [SnapshotStore.save]).
  final DateTime? updatedAt;

  MissionStep? get nextStep => cursor < steps.length ? steps[cursor] : null;

  bool get isComplete =>
      steps.isNotEmpty &&
      steps.every(
        (s) =>
            s.status == MissionStepStatus.done ||
            s.status == MissionStepStatus.skipped,
      );

  ({int hasDone, int total}) get progress {
    final hasDone = steps
        .where((s) => s.status == MissionStepStatus.done)
        .length;
    return (hasDone: hasDone, total: steps.length);
  }

  /// Returns a copy with [stepId] marked done and the cursor advanced past
  /// it. Status becomes [MissionDocumentStatus.running] if still pending.
  MissionDocument withStepDone(String stepId) {
    final index = steps.indexWhere((s) => s.id == stepId);
    if (index < 0) return this;
    final newSteps = <MissionStep>[
      for (var i = 0; i < steps.length; i++)
        i == index ? steps[i].withStatus(MissionStepStatus.done) : steps[i],
    ];
    final newCursor = index + 1 > cursor ? index + 1 : cursor;
    return MissionDocument(
      missionId: missionId,
      role: role,
      goal: goal,
      feature: feature,
      steps: newSteps,
      cursor: newCursor,
      status: status == MissionDocumentStatus.pending
          ? MissionDocumentStatus.running
          : status,
      heldScopes: heldScopes,
      budget: budget,
      updatedAt: updatedAt,
    );
  }

  MissionDocument withStatus(MissionDocumentStatus status) => MissionDocument(
    missionId: missionId,
    role: role,
    goal: goal,
    feature: feature,
    steps: steps,
    cursor: cursor,
    status: status,
    heldScopes: heldScopes,
    budget: budget,
    updatedAt: updatedAt,
  );

  MissionDocument withHeldScopes(List<String> scopes) => MissionDocument(
    missionId: missionId,
    role: role,
    goal: goal,
    feature: feature,
    steps: steps,
    cursor: cursor,
    status: status,
    heldScopes: scopes,
    budget: budget,
    updatedAt: updatedAt,
  );

  MissionDocument withUpdatedAt(DateTime at) => MissionDocument(
    missionId: missionId,
    role: role,
    goal: goal,
    feature: feature,
    steps: steps,
    cursor: cursor,
    status: status,
    heldScopes: heldScopes,
    budget: budget,
    updatedAt: at,
  );

  MissionDocument markStepRunning(String stepId) {
    final index = steps.indexWhere((s) => s.id == stepId);
    if (index < 0) return this;
    final newSteps = <MissionStep>[
      for (var i = 0; i < steps.length; i++)
        i == index ? steps[i].withStatus(MissionStepStatus.running) : steps[i],
    ];
    return MissionDocument(
      missionId: missionId,
      role: role,
      goal: goal,
      feature: feature,
      steps: newSteps,
      cursor: cursor,
      status: MissionDocumentStatus.running,
      heldScopes: heldScopes,
      budget: budget,
      updatedAt: updatedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'missionId': missionId,
    'role': role.name,
    'goal': goal,
    'feature': feature,
    'steps': <Object?>[for (final s in steps) s.toJson()],
    'cursor': cursor,
    'status': status.name,
    'heldScopes': heldScopes,
    'budget': budget?.toJson(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  static MissionDocument fromJson(Map<String, Object?> json) {
    return MissionDocument(
      missionId: json['missionId'] as String,
      role: AgentRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => AgentRole.builder,
      ),
      goal: json['goal'] as String? ?? '',
      feature: json['feature'] as String? ?? '',
      steps: <MissionStep>[
        for (final s in (json['steps'] as List? ?? const <Object?>[]))
          MissionStep.fromJson((s as Map).cast<String, Object?>()),
      ],
      cursor: json['cursor'] as int? ?? 0,
      status: MissionDocumentStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => MissionDocumentStatus.pending,
      ),
      heldScopes: <String>[
        for (final s in (json['heldScopes'] as List? ?? const <Object?>[]))
          s as String,
      ],
      budget: json['budget'] == null
          ? null
          : MissionBudgetSpec.fromJson(
              (json['budget'] as Map).cast<String, Object?>(),
            ),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// Crash-safe snapshot persistence: atomic writes (tmp file + rename) so a
/// `kill -9` mid-save can never produce a torn document.
class SnapshotStore {
  SnapshotStore(this.rootPath) {
    Directory(rootPath).createSync(recursive: true);
  }

  final String rootPath;

  File _file(String missionId) => File('$rootPath/$missionId.mission.json');
  File _tmp(String missionId) => File('$rootPath/$missionId.mission.json.tmp');

  /// Atomically persist [doc].
  void save(MissionDocument doc) {
    final stamped = doc.withUpdatedAt(DateTime.now().toUtc());
    final tmp = _tmp(doc.missionId);
    tmp.writeAsStringSync(_encode(stamped), flush: true);
    tmp.renameSync(_file(doc.missionId).path);
  }

  /// Load a snapshot, or null when the mission is unknown.
  MissionDocument? load(String missionId) {
    final f = _file(missionId);
    if (!f.existsSync()) return null;
    return MissionDocument.fromJson(_decode(f.readAsStringSync()));
  }

  /// Whether a snapshot exists for [missionId].
  bool exists(String missionId) => _file(missionId).existsSync();
}

String _encode(MissionDocument doc) {
  // Minimal, dependency-free JSON writer (stable key order for tests).
  final json = doc.toJson();
  final buf = StringBuffer('{');
  var first = true;
  for (final key in json.keys) {
    if (!first) buf.write(',');
    first = false;
    buf
      ..write('"')
      ..write(key)
      ..write('":')
      ..write(_value(json[key]));
  }
  buf.write('}');
  return buf.toString();
}

String _value(Object? v) {
  if (v == null) return 'null';
  if (v is num || v is bool) return '$v';
  if (v is String) return '"${_escape(v)}"';
  if (v is DateTime) return '"${v.toIso8601String()}"';
  if (v is List) {
    return '[${[for (final e in v) _value(e)].join(',')}]';
  }
  if (v is Map) {
    final parts = <String>[];
    for (final k in v.keys.toList()) {
      parts.add('"${_escape('$k')}":${_value(v[k])}');
    }
    return '{${parts.join(',')}}';
  }
  return '"$v"';
}

String _escape(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll('"', '\\"')
    .replaceAll('\n', '\\n')
    .replaceAll('\r', '\\r')
    .replaceAll('\t', '\\t');

Map<String, Object?> _decode(String raw) {
  // Delegate to dart:convert for parsing (writing is what we keep atomic
  // and dependency-stable).
  return (const JsonDecoder().convert(raw) as Map).cast<String, Object?>();
}
