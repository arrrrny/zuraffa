import 'package:test/test.dart';
import 'package:zuraffa/src/agent/policy/policy_shell.dart';

void main() {
  group('PermissionRegistry (FR-001)', () {
    test('lookup returns registered risk level', () {
      final r = PermissionRegistry(entries: {'tool_a': RiskLevel.confirm});
      expect(r.lookup('tool_a'), equals(RiskLevel.confirm));
    });

    test('lookup falls back to safe when no entry and no fallback', () {
      final r = PermissionRegistry();
      expect(r.lookup('unknown_tool'), equals(RiskLevel.safe));
    });

    test('lookup uses fallback when provided (FR-012)', () {
      final r = PermissionRegistry();
      expect(
        r.lookup('unknown_tool', fallback: RiskLevel.admin),
        equals(RiskLevel.admin),
      );
    });

    test('most-restrictive wins on conflict (edge case)', () {
      final r = PermissionRegistry();
      r.register('tool_x', RiskLevel.safe);
      r.register('tool_x', RiskLevel.confirm);
      expect(r.lookup('tool_x'), equals(RiskLevel.confirm));

      r.register('tool_x', RiskLevel.safe);
      // Still confirm — most restrictive wins.
      expect(r.lookup('tool_x'), equals(RiskLevel.confirm));
    });

    test('RiskLevel.mostRestrictive ordering (admin > confirm > safe)', () {
      expect(
        RiskLevel.safe.mostRestrictive(RiskLevel.admin),
        equals(RiskLevel.admin),
      );
      expect(
        RiskLevel.confirm.mostRestrictive(RiskLevel.safe),
        equals(RiskLevel.confirm),
      );
      expect(
        RiskLevel.admin.mostRestrictive(RiskLevel.confirm),
        equals(RiskLevel.admin),
      );
    });
  });

  group('ToolGatingHook (FR-001..004, FR-012)', () {
    test('safe-tier auto-executes (FR-001 acceptance 1)', () async {
      final hook = ToolGatingHook(
        registry: PermissionRegistry(entries: {'safe_tool': RiskLevel.safe}),
        approvalCallback: (_) async => false,
      );
      final decision = await hook.beforeToolCall(ToolCallContext(
        missionId: 'm1',
        toolName: 'safe_tool',
        args: {},
        isInternalMission: false,
        toolAllowlist: null,
        toolClass: 'io',
      ));
      expect(decision, isA<HookDecisionAllow>());
    });

    test('confirm-tier blocks until approved (FR-002 acceptance 2)', () async {
      final hook = ToolGatingHook(
        registry:
            PermissionRegistry(entries: {'confirm_tool': RiskLevel.confirm}),
        approvalCallback: (_) async => true,
      );
      final decision = await hook.beforeToolCall(ToolCallContext(
        missionId: 'm1',
        toolName: 'confirm_tool',
        args: {},
        isInternalMission: false,
        toolAllowlist: null,
        toolClass: 'io',
      ));
      expect(decision, isA<HookDecisionAllow>());
    });

    test('confirm-tier denies on user rejection', () async {
      final hook = ToolGatingHook(
        registry:
            PermissionRegistry(entries: {'confirm_tool': RiskLevel.confirm}),
        approvalCallback: (_) async => false,
      );
      final decision = await hook.beforeToolCall(ToolCallContext(
        missionId: 'm1',
        toolName: 'confirm_tool',
        args: {},
        isInternalMission: false,
        toolAllowlist: null,
        toolClass: 'io',
      ));
      expect(decision, isA<HookDecisionDeny>());
      expect(
        (decision as HookDecisionDeny).reason,
        contains('user denied'),
      );
    });

    test('confirm-tier denies on timeout (FR-002 acceptance 3)', () async {
      final hook = ToolGatingHook(
        registry:
            PermissionRegistry(entries: {'confirm_tool': RiskLevel.confirm}),
        approvalCallback: (_) async {
          await Future<void>.delayed(const Duration(seconds: 5));
          return true;
        },
        confirmTimeout: const Duration(milliseconds: 50),
      );
      final decision = await hook.beforeToolCall(ToolCallContext(
        missionId: 'm1',
        toolName: 'confirm_tool',
        args: {},
        isInternalMission: false,
        toolAllowlist: null,
        toolClass: 'io',
      ));
      expect(decision, isA<HookDecisionDeny>());
      expect(
        (decision as HookDecisionDeny).reason,
        contains('timed out'),
      );
    });

    test('admin-tier denied for non-internal mission (FR-003 acceptance 4)',
        () async {
      final hook = ToolGatingHook(
        registry:
            PermissionRegistry(entries: {'admin_tool': RiskLevel.admin}),
        approvalCallback: (_) async => true,
      );
      final decision = await hook.beforeToolCall(ToolCallContext(
        missionId: 'm1',
        toolName: 'admin_tool',
        args: {},
        isInternalMission: false,
        toolAllowlist: null,
        toolClass: 'io',
      ));
      expect(decision, isA<HookDecisionDeny>());
      expect(
        (decision as HookDecisionDeny).reason,
        contains('denied for non-internal mission'),
      );
    });

    test('admin-tier allowed for internal mission (FR-003 acceptance 5)',
        () async {
      final hook = ToolGatingHook(
        registry:
            PermissionRegistry(entries: {'admin_tool': RiskLevel.admin}),
        approvalCallback: (_) async => true,
      );
      final decision = await hook.beforeToolCall(ToolCallContext(
        missionId: 'm1',
        toolName: 'admin_tool',
        args: {},
        isInternalMission: true,
        toolAllowlist: null,
        toolClass: 'io',
      ));
      expect(decision, isA<HookDecisionAllow>());
    });

    test('per-mission allowlist overrides risk level (FR-004)', () async {
      final hook = ToolGatingHook(
        registry: PermissionRegistry(entries: {'safe_tool': RiskLevel.safe}),
        approvalCallback: (_) async => true,
      );
      final decision = await hook.beforeToolCall(ToolCallContext(
        missionId: 'm1',
        toolName: 'safe_tool',
        args: {},
        isInternalMission: false,
        toolAllowlist: {'other_tool'},
        toolClass: 'io',
      ));
      expect(decision, isA<HookDecisionDeny>());
      expect(
        (decision as HookDecisionDeny).reason,
        contains('not in per-mission allowlist'),
      );
    });

    test('unregistered tool falls back to declared risk (FR-012)', () async {
      // Registry is empty, so an unregistered tool must resolve through its
      // self-declared risk instead of silently becoming `safe` (fail-open).
      final hook = ToolGatingHook(
        registry: PermissionRegistry(),
        approvalCallback: (_) async => true,
      );
      final decision = await hook.beforeToolCall(ToolCallContext(
        missionId: 'm1',
        toolName: 'unknown_admin_tool',
        args: {},
        isInternalMission: false,
        toolAllowlist: null,
        toolClass: 'io',
        declaredRisk: RiskLevel.admin,
      ));
      expect(decision, isA<HookDecisionDeny>());
      expect(
        (decision as HookDecisionDeny).reason,
        contains('admin-tier'),
      );
    });
  });

  group('MissionBudgetHook (FR-005, FR-006)', () {
    test('max-calls exceeded → cancel with calls reason (SC-002)', () async {
      final breaches = <BudgetBreach>[];
      final hook = MissionBudgetHook(
        budget: const MissionBudget(maxCalls: 2),
        onBreach: breaches.add,
      );
      await hook.onMissionStart('m1');

      // First two calls allowed.
      var d = await hook.beforeToolCall(ToolCallContext(
        missionId: 'm1',
        toolName: 't',
        args: {},
        isInternalMission: false,
        toolAllowlist: null,
        toolClass: 'io',
      ));
      expect(d, isA<HookDecisionAllow>());
      await hook.afterToolCall(
        ToolCallContext(
          missionId: 'm1',
          toolName: 't',
          args: {},
          isInternalMission: false,
          toolAllowlist: null,
          toolClass: 'io',
        ),
        ToolResult(payload: null),
      );

      d = await hook.beforeToolCall(ToolCallContext(
        missionId: 'm1',
        toolName: 't',
        args: {},
        isInternalMission: false,
        toolAllowlist: null,
        toolClass: 'io',
      ));
      expect(d, isA<HookDecisionAllow>());
      await hook.afterToolCall(
        ToolCallContext(
          missionId: 'm1',
          toolName: 't',
          args: {},
          isInternalMission: false,
          toolAllowlist: null,
          toolClass: 'io',
        ),
        ToolResult(payload: null),
      );

      // Third call → cancel.
      d = await hook.beforeToolCall(ToolCallContext(
        missionId: 'm1',
        toolName: 't',
        args: {},
        isInternalMission: false,
        toolAllowlist: null,
        toolClass: 'io',
      ));
      expect(d, isA<HookDecisionCancelMission>());
      expect(
        (d as HookDecisionCancelMission).reason,
        contains('max-calls'),
      );
      expect(breaches, hasLength(1));
      expect(breaches.first.dimension, equals(BudgetDimension.calls));
    });

    test('max-tokens exceeded → cancel with tokens reason', () async {
      final breaches = <BudgetBreach>[];
      final hook = MissionBudgetHook(
        budget: const MissionBudget(maxTokens: 100),
        onBreach: breaches.add,
      );
      await hook.onMissionStart('m1');

      // First call uses 100 tokens — uses the full budget.
      var d = await hook.beforeToolCall(ToolCallContext(
        missionId: 'm1',
        toolName: 't',
        args: {},
        isInternalMission: false,
        toolAllowlist: null,
        toolClass: 'io',
      ));
      expect(d, isA<HookDecisionAllow>());
      await hook.afterToolCall(
        ToolCallContext(
          missionId: 'm1',
          toolName: 't',
          args: {},
          isInternalMission: false,
          toolAllowlist: null,
          toolClass: 'io',
        ),
        ToolResult(payload: null, tokenUsage: 100),
      );

      // Second call: tracker.tokens (100) >= budget.maxTokens (100) → cancel.
      d = await hook.beforeToolCall(ToolCallContext(
        missionId: 'm1',
        toolName: 't',
        args: {},
        isInternalMission: false,
        toolAllowlist: null,
        toolClass: 'io',
      ));
      expect(d, isA<HookDecisionCancelMission>());
      expect(
        (d as HookDecisionCancelMission).reason,
        contains('max-tokens'),
      );
    });

    test('max-calls=0 → immediate cancel on first call (edge case)',
        () async {
      final breaches = <BudgetBreach>[];
      final hook = MissionBudgetHook(
        budget: const MissionBudget(maxCalls: 0),
        onBreach: breaches.add,
      );
      await hook.onMissionStart('m1');

      final d = await hook.beforeToolCall(ToolCallContext(
        missionId: 'm1',
        toolName: 't',
        args: {},
        isInternalMission: false,
        toolAllowlist: null,
        toolClass: 'io',
      ));
      expect(d, isA<HookDecisionCancelMission>());
      expect(breaches, isNotEmpty);
    });

    test('budget-degrade callback fires on breach (FR-013)', () async {
      final breaches = <BudgetBreach>[];
      final hook = MissionBudgetHook(
        budget: const MissionBudget(maxCalls: 1),
        onBreach: (_) {},
        degradeCallback: breaches.add,
      );
      await hook.onMissionStart('m1');

      // First call allowed.
      await hook.beforeToolCall(ToolCallContext(
        missionId: 'm1',
        toolName: 't',
        args: {},
        isInternalMission: false,
        toolAllowlist: null,
        toolClass: 'io',
      ));
      await hook.afterToolCall(
        ToolCallContext(
          missionId: 'm1',
          toolName: 't',
          args: {},
          isInternalMission: false,
          toolAllowlist: null,
          toolClass: 'io',
        ),
        ToolResult(payload: null),
      );

      // Second call → cancel + degrade callback fired.
      await hook.beforeToolCall(ToolCallContext(
        missionId: 'm1',
        toolName: 't',
        args: {},
        isInternalMission: false,
        toolAllowlist: null,
        toolClass: 'io',
      ));
      expect(breaches, isNotEmpty);
      expect(breaches.first.dimension, equals(BudgetDimension.calls));
    });

    test('per-tool-class seconds exceeded → cancel with one breach (T026)',
        () async {
      // webview class capped at 100ms. The per-tool-class budget dimension
      // was inert because duration was never recorded (FR-005 fix).
      final breaches = <BudgetBreach>[];
      final hook = MissionBudgetHook(
        budget: MissionBudget(
          perToolClassMax: {'webview': const Duration(milliseconds: 100)},
        ),
        onBreach: breaches.add,
      );
      await hook.onMissionStart('m1');

      final ctx = (String name) => ToolCallContext(
            missionId: 'm1',
            toolName: name,
            args: {},
            isInternalMission: false,
            toolAllowlist: null,
            toolClass: 'webview',
          );

      // Call 0: 80ms — under the limit, allowed, no breach.
      var d = await hook.beforeToolCall(ctx('v0'));
      expect(d, isA<HookDecisionAllow>());
      await hook.afterToolCall(
        ctx('v0'),
        ToolResult(payload: null, duration: const Duration(milliseconds: 80)),
      );

      // Call 1: another 80ms → 160ms cumulative > 100ms. afterToolCall
      // records the breach. The NEXT beforeToolCall re-detects the same
      // dimension but must NOT replay the event (FR-005/FR-006 dedup).
      d = await hook.beforeToolCall(ctx('v1'));
      expect(d, isA<HookDecisionAllow>());
      await hook.afterToolCall(
        ctx('v1'),
        ToolResult(payload: null, duration: const Duration(milliseconds: 80)),
      );

      d = await hook.beforeToolCall(ctx('v2'));
      expect(d, isA<HookDecisionCancelMission>());
      expect(
        (d as HookDecisionCancelMission).reason,
        contains('per-tool-class'),
      );

      // Exactly one breach event for the per-tool-class dimension, despite
      // it being reported from both afterToolCall and the next beforeToolCall.
      expect(breaches, hasLength(1));
      expect(breaches.first.dimension, equals(BudgetDimension.perToolClass));
    });
  });
}
