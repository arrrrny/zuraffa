**Template Version**: `zuraffa-1.0`

# Plan: 1344-agent-runtime-barrel-collisions

## Technical Context

- **Language/toolchain**: pure Dart (Dart SDK ^3.11.0; built against Dart
  3.13.3 stable). No Flutter SDK involved — `zuraffa` is a pure-Dart package
  and the agent runtime subtree is pure-Dart by constitution.
- **Feature surface** (issue #1344 hard constraint: ONLY the barrel exports
  change; no runtime symbol is renamed and no `lib/src/agent/**`
  implementation is touched):
  - `lib/zuraffa.dart` — the default barrel carries FOUR `src/agent/**`
    export sites today (this is the root cause):
      1. `export 'src/agent/ui_render/ui_render.dart' hide ValidationResult, ValidationError, MissionTraceRecorder;` (spec 023)
      2. `export 'src/agent/kernel/agent_kernel.dart' hide CancelToken, Mission, MissionEvent, MissionEventCompleted, MissionEventFailed;` (spec 026)
      3. `export 'src/agent/policy/policy_shell.dart' hide ToolCallContext;` (spec 027)
      4. `export 'src/agent/runtime/agent_runtime_plugin.dart' hide McpTool, AgentHook, McpToolRegistry, AgentKernel;` (spec 028)
    These transitively re-export the generic agent-domain names that collide
    with ecosystem consumers: `LlmClient` (runtime/llm_client.dart via site
    4), `RiskTier` (runtime/mission.dart via site 4), `ToolResult`
    (policy/policy_hook.dart via site 3), plus `StatefulAgent`,
    `MissionTrace`, `MissionBudget`, and the rest of the runtime surface.
  - `lib/zuraffa/agent.dart` — NEW dedicated barrel (does not exist today;
    there is no `lib/zuraffa/` directory yet). It re-homes the four export
    sites verbatim (relative paths adjusted to `../src/agent/...`), so the
    gated surface is byte-for-byte what the default barrel used to expose.
- **Mechanism precedent**: the barrel already resolves same-name collisions
  with `hide` clauses at the export sites (`ToolCallContext` hidden from the
  policy shell; ui_render's `ValidationResult`/`MissionTraceRecorder` hidden
  against plugin-lifecycle and the policy shell). The chosen fix applies the
  strongest form of the same mechanism: hide the ENTIRE agent runtime from
  the default barrel by removing the sites, and give it a first-class
  dedicated import — the same split Flutter uses for material vs widgets.
- **Why gating (not per-name hides)**: hiding `LlmClient`/`RiskTier`/
  `ToolResult` per-name in the default barrel would fix zuraffa_agent's
  three reported names but leave every other agent-domain name
  (`StatefulAgent`, `MissionTrace`, `MissionBudget`, `KernelStatus`, ...)
  colliding with the next ecosystem package. Narrowing the default barrel
  removes the whole collision class and matches acceptance criterion 1
  ("MUST NOT be re-exported from zuraffa.dart").
- **Intra-agent conflicts**: the four sites overlap (kernel vs runtime
  `Mission`/`MissionEvent`; kernel vs runtime `AgentKernel`; ui_render vs
  policy `MissionTraceRecorder`). The existing per-site `hide` clauses
  resolve these; keeping them verbatim in `agent.dart` guarantees no NEW
  ambiguity is introduced inside the dedicated barrel.
- **Test strategy**: ambiguity is a compile-time property, so the behavioral
  tests are (a) a consumer-fixture library declaring `LlmClient`/`RiskTier`/
  `ToolResult`/`StatefulAgent`/`MissionTrace`/`MissionBudget` imported
  alongside `package:zuraffa/zuraffa.dart` — pre-fix this file FAILS TO
  COMPILE with ambiguous-import errors (recorded red evidence), post-fix it
  resolves to the fixture; (b) a dedicated-barrel test referencing runtime
  symbols and asserting type identity with direct deep imports (pre-fix:
  `package:zuraffa/agent.dart` does not exist → compile failure = red);
  (c) a source-level guard test encoding the SC-1/SC-2 grep gates
  (`grep -n "agent/" lib/zuraffa.dart` → zero matches; dedicated barrel
  carries the four sites). zuraffa_agent itself is unpublished (pre-publish
  gate of zuraffa_agent 0.1.0) and MUST NOT be touched (#1344 hard
  constraint), so the fixture simulates "any ecosystem consumer with
  same-named domain entities".
- **Blast-radius check** (done in plan phase): repo-wide grep over all
  default-barrel importers (257 files in bin/, test/, lib/, example/, apps/,
  tool/, benchmark/) for agent-runtime symbol usage found ZERO real
  consumers (the single grep hit, `lib/src/plugins/mcp/builders/
  mcp_scaffold_builder.dart`, matched `McpToolResult` — a CORE MCP module
  type that stays in the default barrel — inside string templates for
  generated code). Removing the four sites breaks nothing internal.

## Success Criteria

- SC-1: `grep -n "agent/" lib/zuraffa.dart` → zero matches.
- SC-2: `lib/zuraffa/agent.dart` exists with the four `../src/agent/...`
  export sites and their verbatim hide clauses.
- SC-3/SC-4: collision test and dedicated-barrel test green (red first).
- SC-5: `dart analyze` clean on changed files; benchmark guard test green.
