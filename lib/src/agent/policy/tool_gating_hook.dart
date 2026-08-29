import 'dart:async';

import 'permission_registry.dart';
import 'policy_hook.dart';

/// Approval callback signature for confirm-tier tools (FR-002).
///
/// The callback receives a typed UI prompt and resolves to `true` (approve)
/// or `false` (deny).
typedef ApprovalCallback = Future<bool> Function(String prompt);

/// Policy hook that gates tool calls based on the [PermissionRegistry]
/// (FR-001, FR-002, FR-003, FR-004, FR-012).
class ToolGatingHook extends PolicyHook {
  ToolGatingHook({
    required this.registry,
    required this.approvalCallback,
    this.confirmTimeout = const Duration(seconds: 30),
  });

  @override
  String get id => 'tool_gating';

  final PermissionRegistry registry;
  final ApprovalCallback approvalCallback;
  final Duration confirmTimeout;

  @override
  Future<HookDecision> beforeToolCall(ToolCallContext ctx) async {
    // FR-004: per-mission allowlist takes precedence over risk level.
    if (ctx.toolAllowlist != null &&
        !ctx.toolAllowlist!.contains(ctx.toolName)) {
      return HookDecisionDeny(
        'tool "${ctx.toolName}" not in per-mission allowlist',
      );
    }

    // FR-012: registry takes precedence, but a tool's self-declared risk
    // (ctx.declaredRisk) is passed as the fallback so unregistered tools
    // degrade to their declared tier instead of silently resolving to safe.
    final level = registry.lookup(ctx.toolName, fallback: ctx.declaredRisk);

    switch (level) {
      case RiskLevel.safe:
        return const HookDecisionAllow();
      case RiskLevel.confirm:
        // FR-002: emit typed UI approval; deny on timeout.
        final prompt = 'Approve tool call: ${ctx.toolName}?';
        try {
          // Use the throwing form of `.timeout` so the timeout branch
          // fires (instead of falling into the `if (!approved)` branch).
          final approved = await approvalCallback(
            prompt,
          ).timeout(confirmTimeout);
          if (!approved) {
            return HookDecisionDeny(
              'user denied confirm-tier tool "${ctx.toolName}"',
            );
          }
          return const HookDecisionAllow();
        } on TimeoutException {
          return HookDecisionDeny(
            'confirm-tier tool "${ctx.toolName}" timed out',
          );
        }
      case RiskLevel.admin:
        // FR-003: denied for non-internal missions, allowed for internal.
        if (!ctx.isInternalMission) {
          return HookDecisionDeny(
            'admin-tier tool "${ctx.toolName}" denied for non-internal mission',
          );
        }
        return const HookDecisionAllow();
    }
  }
}
