# Bug Assessment: mcp: land PR #374 and productionize the app-side MCP runtime

- **Slug**: mcp-productionize-app-runtime
- **Created**: 2026-08-28T00:00:00Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/384
- **Verdict**: valid (productionization gap, not a regression)
- **Severity**: high

## Report (verbatim or summarized)

Issue #384 tracks productionizing the MCP app-side runtime added by PR #374 (now MERGED). PR #374 added `McpTool`, `McpToolRegistry`, `McpSseServer`, `McpServerPlugin`, `McpStdioServer`, `McpDispatcher`, codegen scaffolder, CLI commands, and 82 tests. The issue identifies 6 remaining productionization requirements that are not yet implemented.

## Symptom

The MCP runtime works as a demo but lacks production hardening: no in-proc serving path (LocalMcpHost adapter), no per-token tool allowlists on SSE, no connection limits or idle timeouts, no `McpToolResult.artifactRef` for large payloads, and incomplete lifecycle management. These gaps block ZikZak AI agent architecture deployment.

## Reproduction

1. Review the merged PR #374 codebase at `lib/src/core/module/mcp_*.dart` and `lib/src/mcp/sse_server.dart`
2. Verify absence of `LocalMcpHost` interface adapter — grep for `LocalMcpHost` yields zero results in source (only in issue.md)
3. Verify `McpToolResult` has no `artifactRef` field — `lib/src/core/module/mcp_tool.dart:30-77` shows only `isError`, `text`, `data`
4. Verify SSE server lacks connection limits and idle timeouts — `lib/src/mcp/sse_server.dart` has no `_SseSession` timeout or max-connections logic
5. Verify no per-token tool allowlist in SSE auth — `McpAuth` validates bearer token but has no tool-level filtering

## Suspected Code Paths

- `lib/src/core/module/mcp_tool.dart:30-77` — `McpToolResult` lacks `artifactRef` field for ref-only large payloads
- `lib/src/mcp/sse_server.dart:42-417` — SSE server lacks connection limits, idle timeouts, per-token tool allowlists
- `lib/src/core/module/mcp_tool_registry.dart:17-79` — `McpToolRegistry` has no `LocalMcpHost` adapter (needed for in-proc bridge to dart_agent_core)
- `lib/src/core/module/mcp_server_plugin.dart:51-214` — `McpServerPlugin` lifecycle hooks exist but no runtime tool registration/unregistration API

## Root Cause Hypothesis

PR #374 delivered functional demo-quality MCP runtime but did not include production hardening features. The issue is a feature enhancement tracking gap, not a code defect. Confidence: high.

## Proposed Remediation

**Preferred**: Implement each requirement as separate, testable changes:

1. **In-proc serving path**: Create `LocalMcpHostAdapter` that wraps `McpToolRegistry` to implement the `LocalMcpHost` interface from dart_agent_core. Place at `lib/src/core/module/mcp_local_host_adapter.dart`.

2. **SSE hardening**: Extend `McpSseServer` with:
   - Per-token tool allowlist (map of token → allowed tool names)
   - Connection limits (max concurrent SSE sessions)
   - Idle timeouts (close sessions after N seconds of inactivity)
   - Graceful shutdown with drain period
   - Structured JSON error responses

3. **McpToolResult.artifactRef**: Add optional `artifactRef` field to `McpToolResult` that holds a reference (URI/ID) instead of marshaling large bodies through transport.

4. **Lifecycle integration**: Ensure `McpServerPlugin` implements full `ZuraffaPlugin` lifecycle (onInit, onDispose, runtime tool register/unregister via registry).

**Files likely to change**:
- `lib/src/core/module/mcp_tool.dart`
- `lib/src/mcp/sse_server.dart`
- `lib/src/core/module/mcp_tool_registry.dart`
- `lib/src/core/module/mcp_server_plugin.dart`
- New: `lib/src/core/module/mcp_local_host_adapter.dart`

**Tests to add or update**:
- `test/plugins/mcp/mcp_sse_server_test.dart` — connection limits, idle timeouts, allowlist tests
- `test/plugins/mcp/mcp_tool_registry_test.dart` — LocalMcpHost adapter integration test
- `test/plugins/mcp/mcp_tool_test.dart` — artifactRef serialization test

## Risks & Considerations

- Breaking API change if `McpToolResult` fields change (minor risk — field is additive)
- dart_agent_core `LocalMcpHost` interface may evolve — track upstream
- SSE hardening changes could affect existing test fixtures (82 tests in PR #374)
- Platform verification (macOS/iOS/Android) requires device testing not possible in CI

## Open Questions

- What is the exact `LocalMcpHost` interface contract from dart_agent_core#2?
- Should per-token allowlists be configured via `McpServerPlugin` constructor or runtime API?
- Is there a target load-test number beyond the stated 1k concurrent tool calls?
