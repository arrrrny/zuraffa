// Issue #1344 — acceptance criterion 3 + 4 / FR-004 / SC-4.
//
// The agent runtime MUST remain accessible for consumers who want it — via
// `package:zuraffa/agent.dart` — and the dedicated barrel must expose the
// SAME declarations a direct deep import exposes (backward compatibility:
// deep-import consumers and dedicated-barrel consumers see identical
// types). Before the fix `package:zuraffa/agent.dart` did not exist, so
// this file failed to compile (uri_does_not_exist) — recorded red evidence.
import 'package:zuraffa/agent.dart';
import 'package:zuraffa/src/agent/policy/policy_hook.dart' as deep_policy;
import 'package:zuraffa/src/agent/runtime/llm_client.dart' as deep_runtime;
import 'package:zuraffa/src/agent/runtime/mission.dart' as deep_mission;
import 'package:zuraffa/src/agent/runtime/stateful_agent.dart' as deep_agent;
import 'package:zuraffa/zuraffa/agent.dart' as nested;
import 'package:test/test.dart';

void main() {
  test(
    'agent runtime is accessible via the dedicated package:zuraffa/agent.dart '
    'barrel',
    () {
      // Runtime-owned resolution: these references compile only when the
      // dedicated barrel exports the runtime symbols. `AgentKernel` also
      // proves the intra-barrel hide arbitration survived the move (it is
      // declared by BOTH kernel/kernel.dart and runtime/agent_kernel.dart;
      // the former wins via the preserved hide clauses).
      Type llm = LlmClient;
      Type stateful = StatefulAgent;
      Type kernel = AgentKernel;
      expect(llm, isNotNull);
      expect(stateful, isNotNull);
      expect(kernel, isNotNull);
      expect(
        RiskTier.values,
        equals([RiskTier.standard, RiskTier.elevated, RiskTier.admin]),
      );
      expect(ToolResult, isNotNull);
    },
  );

  test('dedicated barrel and direct deep imports expose identical declarations '
      '(backward compatibility)', () {
    Type barrelLlm = LlmClient;
    Type deepLlm = deep_runtime.LlmClient;
    expect(barrelLlm, same(deepLlm));

    Type barrelTool = ToolResult;
    Type deepTool = deep_policy.ToolResult;
    expect(barrelTool, same(deepTool));

    Type barrelTier = RiskTier;
    Type deepTier = deep_mission.RiskTier;
    expect(barrelTier, same(deepTier));

    Type barrelStateful = StatefulAgent;
    Type deepStateful = deep_agent.StatefulAgent;
    expect(barrelStateful, same(deepStateful));
  });

  test('both dedicated import URIs (package:zuraffa/agent.dart and '
      'package:zuraffa/zuraffa/agent.dart) expose identical declarations', () {
    Type facadeLlm = LlmClient;
    Type nestedLlm = nested.LlmClient;
    expect(facadeLlm, same(nestedLlm));

    Type facadeTier = RiskTier;
    Type nestedTier = nested.RiskTier;
    expect(facadeTier, same(nestedTier));
  });
}
