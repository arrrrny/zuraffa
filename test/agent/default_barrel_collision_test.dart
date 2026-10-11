// Issue #1344 — acceptance criterion 2 / FR-003 / SC-3.
//
// A consumer imports BOTH `package:zuraffa/zuraffa.dart` AND its own
// agent-domain entity library in one file and references the colliding
// names. Before the barrel fix this file did not even COMPILE: every name
// below that the default barrel also exported produced an ambiguous-import
// error ("'X' is imported from both ..."). After the fix the default
// barrel no longer re-exports the agent runtime, so every reference
// resolves unambiguously to the CONSUMER's declaration — asserted here via
// fixture-only markers/values that cannot exist on zuraffa's runtime types.
import 'package:test/test.dart';

// The default-barrel import MUST stay even though nothing from it is
// referenced anymore: it is the collision party under test. Post-fix it
// carries none of the agent-domain names (which is exactly the point), so
// the analyzer would flag it unused without the ignore below.
// ignore: unused_import
import 'package:zuraffa/zuraffa.dart';

import '../fixtures/agent_collision_consumer_fixture.dart';

void main() {
  test('default barrel does not collide with consumer agent-domain entities '
      '(LlmClient, RiskTier, ToolResult)', () {
    // Fixture-only markers: resolving these names to zuraffa's agent
    // runtime declarations would be a compile error (the runtime types
    // carry no `fixtureOwner` static, and the runtime RiskTier enum has no
    // `critical` value).
    expect(LlmClient.fixtureOwner, 'consumer-fixture');
    expect(RiskTier.critical, isA<RiskTier>());
    expect(RiskTier.values.map((e) => e.name), isNot(contains('standard')));
    expect(ToolResult.fixtureOwner, 'consumer-fixture');
  });

  test('default barrel does not collide with the wider agent-domain name class '
      '(StatefulAgent, MissionTrace, MissionBudget)', () {
    // The three reported names are instances of a collision CLASS: any
    // agent-domain name re-exported by the default barrel collides with
    // the next ecosystem package that declares the same name. Gating the
    // whole runtime (not just the three reported names) removes the class.
    expect(StatefulAgent.fixtureOwner, 'consumer-fixture');
    expect(MissionTrace.fixtureOwner, 'consumer-fixture');
    expect(MissionBudget.fixtureOwner, 'consumer-fixture');
  });
}
