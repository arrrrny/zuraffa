**Template Version**: `zuraffa-1.0`

# Spec: 1344-agent-runtime-barrel-collisions

## Summary

Switching `zuraffa_agent` from a pinned git development ref to hosted
`zuraffa: ^6.1.0` (resolves 6.2.x) broke ecosystem consumers at load time:
zuraffa 6.2.x's agent runtime (`lib/src/agent/**`: kernel, policy, runtime,
shell, ui_render) is re-exported from the default `package:zuraffa/zuraffa.dart`
barrel, and `zuraffa_agent` defines its own domain entities with the same
names (its specs 031/034/051 predate the runtime). Every file importing both
packages gets ambiguity errors — 5 files / 8 error sites in `zuraffa_agent`,
including `LlmClient`, `RiskTier`, and `ToolResult` — and the same breakage
is likely for ANY ecosystem consumer with same-named domain entities. This
feature narrows the default barrel: the agent runtime moves out of
`zuraffa.dart` and is gated behind a dedicated `package:zuraffa/agent.dart`
barrel (the same split pattern as Flutter's material vs widgets), reusing the
barrel's existing `hide` mechanism precedent (already used for
`ToolCallContext` and the ui_render `ValidationResult`/`MissionTraceRecorder`
collisions). The runtime itself is NOT removed, NOT renamed, and its
implementation is NOT changed — the fix is a non-breaking narrowing of the
default export surface.

## Acceptance Scenarios

1. **Given** the default barrel `package:zuraffa/zuraffa.dart` **When** a
   consumer inspects its export directives (or greps it for `agent/`)
   **Then** ZERO `src/agent/**` exports (and zero `agent/` path references)
   remain in `lib/zuraffa.dart`; the agent runtime is not re-exported from
   the default barrel at all.
2. **Given** an ecosystem consumer that declares its own agent-domain
   entities named `LlmClient`, `RiskTier`, and `ToolResult` (as
   `zuraffa_agent` does) **When** the consumer imports BOTH
   `package:zuraffa/zuraffa.dart` AND its own entity library in one file and
   references those names **Then** the names resolve unambiguously to the
   CONSUMER's declarations — no ambiguous-import compile error is produced
   for `LlmClient`, `RiskTier`, `ToolResult`, or any other agent-domain name
   (verified for `StatefulAgent`, `MissionTrace`, `MissionBudget` too).
3. **Given** a consumer that WANTS the agent runtime **When** it imports
   `package:zuraffa/agent.dart` **Then** the full agent runtime surface is
   accessible exactly as before (ui_render, kernel, policy, runtime plugin
   entry libraries, with the same `hide` clauses the default barrel carried);
   referencing `LlmClient`, `RiskTier`, `ToolResult`, `StatefulAgent`,
   `AgentKernel` compiles and resolves to zuraffa's runtime declarations.
4. **Given** backward compatibility **When** a consumer imports
   `package:zuraffa/src/agent/**` files directly, or imports the new
   dedicated agent barrel **Then** they resolve to the SAME declarations as
   before the fix (type-identical: the deep import and the dedicated barrel
   expose the identical `LlmClient` type); no existing non-agent export in
   the default barrel changes (the barrel's benchmark export guard test
   stays green).

## Functional Requirements

- **FR-001** (default barrel narrowing): `lib/zuraffa.dart` MUST NOT contain
  any export directive (or path reference) matching `agent/` — the four
  `src/agent/**` export sites (ui_render, kernel, policy shell, runtime
  plugin) are removed from the default barrel.
- **FR-002** (dedicated agent barrel): a new `lib/zuraffa/agent.dart` MUST
  export the agent runtime via the four former entry libraries
  (`../src/agent/ui_render/ui_render.dart`, `../src/agent/kernel/agent_kernel.dart`,
  `../src/agent/policy/policy_shell.dart`,
  `../src/agent/runtime/agent_runtime_plugin.dart`), preserving the existing
  `hide` clauses verbatim (`hide ValidationResult, ValidationError,
  MissionTraceRecorder` / `hide CancelToken, Mission, MissionEvent,
  MissionEventCompleted, MissionEventFailed` / `hide ToolCallContext` /
  `hide McpTool, AgentHook, McpToolRegistry, AgentKernel`) so the agent
  surface is byte-for-byte the surface the default barrel used to carry.
- **FR-003** (no ecosystem collisions): importing
  `package:zuraffa/zuraffa.dart` alongside a library declaring consumer-owned
  `LlmClient` / `RiskTier` / `ToolResult` (and other agent-domain names) and
  referencing those names MUST compile without ambiguous-import errors, the
  references resolving to the consumer's declarations.
- **FR-004** (runtime accessibility preserved): `package:zuraffa/agent.dart`
  MUST expose the agent runtime symbols (`LlmClient`, `RiskTier`,
  `ToolResult`, `StatefulAgent`, `AgentKernel`, ...) resolving to the SAME
  declarations that direct deep imports
  (`package:zuraffa/src/agent/**`) expose.
- **FR-005** (no runtime changes): no symbol in `lib/src/agent/**` is
  renamed, moved, or edited; the ONLY files changed are `lib/zuraffa.dart`
  (narrowed) and `lib/zuraffa/agent.dart` (added), plus tests and spec
  artifacts.

## Success Criteria

- SC-1: `grep -n "agent/" lib/zuraffa.dart` returns zero matches.
- SC-2: `test -f lib/zuraffa/agent.dart` succeeds and the file carries the
  four former agent export sites with their hide clauses.
- SC-3: the collision test (default barrel + consumer fixture referencing
  `LlmClient`, `RiskTier`, `ToolResult`, `StatefulAgent`, `MissionTrace`,
  `MissionBudget`) compiles and passes with fixture-owned resolution.
- SC-4: the dedicated-barrel test compiles and passes with runtime-owned
  resolution, type-identical to direct deep imports.
- SC-5: `dart analyze` is clean on the changed barrel files; the existing
  barrel guard test (`test/pubignore_export_guard_test.dart`) stays green.
