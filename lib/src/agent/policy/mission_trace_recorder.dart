import 'dart:async';

import 'mission_trace.dart';
import 'policy_hook.dart';

/// Records the mission trace (FR-007, FR-008, FR-009).
///
/// **Single-mission by design.** One recorder instance records exactly one
/// mission: it is constructed for a fixed [missionId] and asserts that every
/// `onMissionStart`/`afterToolCall` it sees belongs to that mission. A
/// [PolicyShell] running multiple missions should hold one recorder per
/// mission (mirroring [MissionBudgetHook]'s per-mission trackers).
///
/// Append-only — records are captured in `afterToolCall` under Dart's
/// single-isolate model (FR-009), so no pending-map or lock is needed. The
/// final [MissionTrace] is materialized via [materialize] when the mission
/// ends.
class MissionTraceRecorder extends PolicyHook {
  MissionTraceRecorder({
    required this.inputHash,
    this.allowlist = const <String>{},
    this.provider,
    this.planSteps = const <String>[],
    this.missionId = 'default',
  }) : _hasher = ArgumentHasher(allowlist: allowlist);

  @override
  String get id => 'mission_trace';

  final String missionId;
  final String inputHash;
  final Set<String> allowlist;
  final String? provider;
  final List<String> planSteps;

  final ArgumentHasher _hasher;
  final List<ToolCallRecord> _records = <ToolCallRecord>[];

  DateTime? _startedAt;
  DateTime? _endedAt;

  @override
  Future<void> onMissionStart(String missionId) async {
    assert(
      missionId == this.missionId,
      'MissionTraceRecorder is single-mission: constructed for '
      '"${this.missionId}" but started for "$missionId"',
    );
    _records.clear();
    _startedAt = DateTime.now();
    _endedAt = null;
  }

  @override
  Future<HookDecision> beforeToolCall(ToolCallContext ctx) async {
    // FR-009: records are appended in `afterToolCall` — no pending map needed.
    return const HookDecisionAllow();
  }

  @override
  Future<ToolResult> afterToolCall(
    ToolCallContext ctx,
    ToolResult result,
  ) async {
    final hashResult = _hasher.hash(ctx.args);
    final record = ToolCallRecord(
      name: ctx.toolName,
      argumentsHash: hashResult.hash,
      cleartextArgs: hashResult.cleartext,
      duration: result.duration,
      status: result.status,
      tokenUsage: result.tokenUsage,
      provider: provider,
    );
    _records.add(record);
    return result;
  }

  @override
  Future<void> onMissionEnd(String missionId) async {
    _endedAt = DateTime.now();
  }

  /// Materializes the final [MissionTrace] (FR-007).
  ///
  /// [status] is the mission-level outcome — defaults to `completed`, but a
  /// mission cancelled by a budget breach should be materialized with
  /// [ToolCallStatus.cancelled] (or `failed`) so the trace stays truthful.
  MissionTrace materialize({
    Object? outcome,
    ToolCallStatus status = ToolCallStatus.completed,
  }) {
    final start = _startedAt ?? DateTime.now();
    final end = _endedAt ?? DateTime.now();
    return MissionTrace(
      missionId: missionId,
      inputHash: inputHash,
      planSteps: planSteps,
      toolCallRecords: List<ToolCallRecord>.from(_records),
      duration: end.difference(start),
      status: status.name,
      tokens: _records.fold(0, (sum, r) => sum + r.tokenUsage),
      provider: provider,
      outcome: outcome,
    );
  }

  /// Number of tool-call records captured so far.
  int get recordCount => _records.length;
}
