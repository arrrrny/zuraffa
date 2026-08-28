/// Agent Policy Shell — framework-default safety/governance layer.
///
/// Ships three composable, individually-disableable policy hooks:
/// - [ToolGatingHook] — tool permission registry (safe / confirm / admin)
///   evaluated before every tool call; per-mission allowlists.
/// - [MissionBudgetHook] — four-dimension budgets (calls, wall-clock, tokens,
///   per-tool-class seconds) with typed budget-exceeded events and cancel.
/// - [MissionTraceRecorder] — hashed-argument Mission Trace JSON with
///   concurrent-streaming integrity and an oversized-result guard.
///
/// Pure-Dart — no `package:flutter` imports. See
/// `specs/027-agent-policy-shell/` for the full spec.
library;

export 'policy_hook.dart';
export 'permission_registry.dart';
export 'tool_gating_hook.dart';
export 'mission_budget.dart';
export 'mission_budget_hook.dart';
export 'mission_trace.dart';
export 'mission_trace_recorder.dart';
export 'oversized_result_guard.dart';
export 'artifact_reference.dart';
export 'policy_shell_class.dart';
