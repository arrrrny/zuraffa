// Issue #1344 — acceptance criterion 1 / FR-001 + FR-002 / SC-1 + SC-2.
//
// Source-level guard encoding the two REQUIRED grep gates from the fix
// protocol:
//   1. `grep -n "agent/" lib/zuraffa.dart` → zero matches (the default
//      barrel no longer references the agent runtime subtree at all — not
//      in export directives, not in comment path references).
//   2. `test -f lib/zuraffa/agent.dart` → the dedicated barrel exists and
//      carries the four former export sites with their hide clauses, so
//      the gated surface is byte-for-byte what the default barrel used to
//      carry.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('SC-1: default barrel carries ZERO agent/ references', () {
    final barrel = File('lib/zuraffa.dart').readAsStringSync();
    final matches = RegExp('agent/').allMatches(barrel).toList();
    expect(
      matches,
      isEmpty,
      reason:
          'lib/zuraffa.dart must not reference the agent runtime subtree. '
          'Gate: grep -n "agent/" lib/zuraffa.dart must return zero matches. '
          'The agent runtime lives behind package:zuraffa/agent.dart.',
    );
  });

  test('SC-2: dedicated agent barrel carries the four former export sites', () {
    final agentBarrel = File('lib/zuraffa/agent.dart');
    expect(
      agentBarrel.existsSync(),
      isTrue,
      reason:
          'lib/zuraffa/agent.dart missing — the agent runtime must '
          'stay accessible via a dedicated barrel (AC 3).',
    );
    final src = agentBarrel.readAsStringSync();
    expect(src, contains("export '../src/agent/ui_render/ui_render.dart'"));
    expect(src, contains("export '../src/agent/kernel/agent_kernel.dart'"));
    expect(src, contains("export '../src/agent/policy/policy_shell.dart'"));
    expect(
      src,
      contains("export '../src/agent/runtime/agent_runtime_plugin.dart'"),
    );
    // The hide clauses are part of the surface contract (they arbitrate the
    // kernel-vs-runtime and ui_render-vs-policy same-name conflicts); they
    // must survive the move verbatim.
    expect(src, contains('hide ToolCallContext'));
    expect(
      src,
      contains('hide McpTool, AgentHook, McpToolRegistry, AgentKernel'),
    );
  });
}
