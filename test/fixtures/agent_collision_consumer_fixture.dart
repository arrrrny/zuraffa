/// Consumer-collision fixture for issue #1344.
///
/// Simulates the ecosystem-collision surface that broke `zuraffa_agent`
/// (and would break ANY ecosystem consumer) when zuraffa 6.2.x started
/// re-exporting the agent runtime from the default
/// `package:zuraffa/zuraffa.dart` barrel: this library declares its OWN
/// domain entities carrying generic agent-domain names — the same NAMES
/// (and the same declaration kinds: class / enum) as the colliding
/// entities zuraffa_agent owns per its specs 031/034/051.
///
/// zuraffa_agent itself is unpublished (pre-publish gate of 0.1.0) and MUST
/// NOT be imported here (#1344 hard constraint: the fix is upstream in
/// zuraffa's barrel and zuraffa_agent is not touched); this fixture stands
/// in for "a consumer with same-named domain entities".
///
/// Each entity carries a distinct `fixtureOwner` marker (and the enum uses
/// deliberately non-runtime value names) so a test can PROVE which
/// declaration a reference resolved to: resolving to zuraffa's runtime
/// declarations instead of these would be a compile error inside the test.
library;

/// Consumer-owned LLM client entity (zuraffa_agent's spec 031 domain
/// entity — NOT zuraffa's `src/agent/runtime/llm_client.dart`).
class LlmClient {
  const LlmClient();

  static const String fixtureOwner = 'consumer-fixture';
}

/// Consumer-owned risk-tier entity — values deliberately differ from the
/// agent runtime's `RiskTier { standard, elevated, admin }` so a reference
/// to [critical] only compiles when THIS declaration wins.
enum RiskTier { low, critical }

/// Consumer-owned tool-result entity (zuraffa_agent's spec 034 entity —
/// NOT zuraffa's `src/agent/policy/policy_hook.dart` [ToolResult]).
class ToolResult {
  const ToolResult();

  static const String fixtureOwner = 'consumer-fixture';
}

/// Consumer-owned stateful agent entity (NOT zuraffa's
/// `src/agent/runtime/stateful_agent.dart` [StatefulAgent]).
class StatefulAgent {
  const StatefulAgent();

  static const String fixtureOwner = 'consumer-fixture';
}

/// Consumer-owned mission-trace entity (NOT zuraffa's
/// `src/agent/policy/mission_trace.dart` [MissionTrace]).
class MissionTrace {
  const MissionTrace();

  static const String fixtureOwner = 'consumer-fixture';
}

/// Consumer-owned mission-budget entity (NOT zuraffa's
/// `src/agent/policy/mission_budget.dart` [MissionBudget]).
class MissionBudget {
  const MissionBudget();

  static const String fixtureOwner = 'consumer-fixture';
}
