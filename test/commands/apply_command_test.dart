import 'dart:io';

import 'package:test/test.dart';
import 'package:args/command_runner.dart';
import 'package:zuraffa/src/commands/apply_command.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_interface.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_registry.dart';
import 'package:zuraffa/src/core/plugin_system/plan_store.dart';

/// Issue #767 — systemic exit-code contract for the plan/apply pipeline.
///
/// `zfa plan` (dry-run) → [PlanStore] → `zfa plan apply` is exactly the
/// automation surface the manifest advertises (an agent previews with a
/// dry-run, stores the plan, applies it later). Every failure path of
/// [ApplyCommand] printed ❌ and still exited 0, so scripts/CI/MCP
/// harnesses read failed applications as successes:
///
///   FR-1: plan not found        → ❌ + exit 64 (bad request family)
///   FR-2: plan invalid          → ❌ + exit 64 (bad request family)
///   FR-3: plugin not found      → ❌ + exit 64 (bad request family)
///   FR-4: execute reports fail  → ❌ + exit 1  (runtime failure, same
///         code the shared CapabilityCommand failure path uses)
///   FR-5: success               → ✅ + exit 0 (regression guard) and
///         the plan is deleted after successful application.
void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('apply_cmd_767_');
    PlanStore.instance.rootDirectory = tmp.path;
  });

  tearDown(() {
    PlanStore.instance.rootDirectory = null;
    tmp.deleteSync(recursive: true);
  });

  ApplyCommand commandWith(PluginRegistry registry) => ApplyCommand(registry);

  CommandRunner<void> runnerWith(ApplyCommand command) =>
      CommandRunner<void>('test', 'test')..addCommand(command);

  /// Runs the apply command hermetically and returns the process exit code
  /// the command opted into (via the `exitCode` setter).
  Future<int> runApply(List<String> args) async {
    exitCode = 0;
    final captured = <int>[];
    // `prints` swallows nothing we need; we only care about exitCode.
    await runnerWith(commandWith(PluginRegistry())).run(args);
    captured.add(exitCode);
    exitCode = 0; // hermetic: never leak a failure code into the suite
    return captured.first;
  }

  test('FR-1 — plan not found exits 64', () async {
    final code = await runApply(['apply', '--plan-id', 'nope']);
    expect(code, equals(64));
  });

  test('FR-2 — invalid plan exits 64', () async {
    await PlanStore.instance.savePlan(
      EffectReport(
        planId: 'bad_plan',
        pluginId: 'some_plugin',
        capabilityName: 'some_cap',
        args: {},
        changes: [],
        isValid: false,
        message: 'schema drift',
      ),
    );
    int code = 0;
    await expectLater(
      () async => code = await runApply(['apply', '--plan-id', 'bad_plan']),
      prints(contains('❌ Plan is invalid')),
    );
    expect(code, equals(64));
  });

  test('FR-3 — plugin not found exits 64', () async {
    await PlanStore.instance.savePlan(
      EffectReport(
        planId: 'orphan_plan',
        pluginId: 'ghost_plugin',
        capabilityName: 'some_cap',
        args: {},
        changes: [],
      ),
    );
    int code = 0;
    await expectLater(
      () async => code = await runApply(['apply', '--plan-id', 'orphan_plan']),
      prints(contains('❌ Plugin not found: ghost_plugin')),
    );
    expect(code, equals(64));
  });

  test('FR-4 — execute failure exits 1', () async {
    final registry = PluginRegistry()..register(MockApplyPlugin(fails: true));
    await PlanStore.instance.savePlan(
      EffectReport(
        planId: 'failing_plan',
        pluginId: 'apply_mock',
        capabilityName: 'apply_cap',
        args: {},
        changes: [],
      ),
    );
    exitCode = 0;
    int code = 0;
    await expectLater(() async {
      await runnerWith(
        commandWith(registry),
      ).run(['apply', '--plan-id', 'failing_plan']);
      code = exitCode;
    }, prints(contains('❌ Failed:')));
    exitCode = 0;
    expect(
      code,
      equals(1),
      reason:
          'capability reported success: false — the plan was NOT applied '
          'but the process reported success (issue #767)',
    );
  });

  test(
    'FR-5 — success keeps exit 0, ✅ framing, and deletes the plan',
    () async {
      final registry = PluginRegistry()
        ..register(MockApplyPlugin(fails: false));
      await PlanStore.instance.savePlan(
        EffectReport(
          planId: 'good_plan',
          pluginId: 'apply_mock',
          capabilityName: 'apply_cap',
          args: {},
          changes: [],
        ),
      );
      exitCode = 0;
      int code = 0;
      await expectLater(
        () async {
          await runnerWith(
            commandWith(registry),
          ).run(['apply', '--plan-id', 'good_plan']);
          code = exitCode;
        },
        prints(
          allOf(contains('✅ Success!'), contains('lib/generated/thing.dart')),
        ),
      );
      exitCode = 0;
      expect(code, equals(0));
      final plan = await PlanStore.instance.loadPlan('good_plan');
      expect(
        plan,
        isNull,
        reason: 'a successfully applied plan must be cleaned up',
      );
    },
  );
}

/// Minimal plugin exposing one capability whose outcome is switchable for
/// the FR-4/FR-5 scenarios.
class MockApplyPlugin extends ZuraffaPlugin {
  final bool fails;
  MockApplyPlugin({required this.fails});

  @override
  String get id => 'apply_mock';
  @override
  String get name => 'Apply Mock';
  @override
  String get version => '1.0.0';

  @override
  List<ZuraffaCapability> get capabilities => [_MockApplyCapability(fails)];
}

class _MockApplyCapability implements ZuraffaCapability {
  final bool fails;
  _MockApplyCapability(this.fails);

  @override
  String get name => 'apply_cap';
  @override
  String get description => 'Mock apply capability';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': <String, dynamic>{},
    'required': [],
  };

  @override
  JsonSchema get outputSchema => <String, dynamic>{};

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async => EffectReport(
    planId: '1',
    pluginId: 'apply_mock',
    capabilityName: 'apply_cap',
    args: args,
    changes: [],
  );

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async => fails
      ? ExecutionResult(success: false, message: 'generation exploded')
      : ExecutionResult(success: true, files: ['lib/generated/thing.dart']);
}
