import 'dart:async';

import 'mission_trace.dart';
import 'policy_hook.dart';

/// Records the mission trace (FR-007, FR-008, FR-009).
///
/// Append-only — concurrent streaming events are safe under Dart's
/// single-isolate model (FR-009). Each [ToolCallRecord] is captured in
/// `afterToolCall`. The final [MissionTrace] is materialized via
/// [materialize] when the mission ends.
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
  final Map<String, Completer<ToolCallRecord>> _pending = <String, Completer<ToolCallRecord>>{};

  DateTime? _startedAt;
  DateTime? _endedAt;

  @override
  Future<void> onMissionStart(String missionId) async {
    _startedAt = DateTime.now();
  }

  @override
  Future<HookDecision> beforeToolCall(ToolCallContext ctx) async {
    // Begin a pending record — `afterToolCall` will complete it.
    // FR-009: trace integrity under concurrent streaming. We rely on
    // single-isolate scheduling; there's no real lock needed.
    _pending[ctx.toolName] = Completer<ToolCallRecord>();
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
      duration: Duration.zero, // (caller can fill in real duration)
      status: 'completed',
      tokenUsage: result.tokenUsage,
      provider: provider,
    );
    _records.add(record);
    _pending[ctx.toolName]?.complete(record);
    return result;
  }

  @override
  Future<void> onMissionEnd(String missionId) async {
    _endedAt = DateTime.now();
  }

  /// Materializes the final [MissionTrace] (FR-007).
  MissionTrace materialize({Object? outcome}) {
    final start = _startedAt ?? DateTime.now();
    final end = _endedAt ?? DateTime.now();
    return MissionTrace(
      missionId: missionId,
      inputHash: inputHash,
      planSteps: planSteps,
      toolCallRecords: List<ToolCallRecord>.from(_records),
      duration: end.difference(start),
      status: 'completed',
      tokens: _records.fold(0, (sum, r) => sum + r.tokenUsage),
      provider: provider,
      outcome: outcome,
    );
  }

  /// Number of tool-call records captured so far.
  int get recordCount => _records.length;
}
