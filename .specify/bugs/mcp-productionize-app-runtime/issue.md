# Bug Issue: mcp: land PR #374 and productionize the app-side MCP runtime (in-proc serving, SSE hardening, lifecycle)

- **Slug**: mcp-productionize-app-runtime
- **Fetched**: 2026-08-28T00:00:00Z
- **Issue**: 384
- **URL**: https://github.com/arrrrny/zuraffa/issues/384
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, zikzak-ai

## Body

PR #374 (`feat/369-mcp-plugin-expose-app-features-as-mcp-tools`) adds the app-side MCP tier: `McpTool`/`McpToolRegistry` runtime (`lib/src/core/module/mcp_*.dart`), `McpSseServer` (HTTP+SSE, Bearer), `McpPlugin` codegen scaffolder, `zfa mcp serve/list-tools` CLI, 82 tests. It is the runtime foundation of ZikZak AI's agent architecture — every device tool and every raptorr cloud tool serves through it. This issue tracks **landing it on `development` and productionizing it** beyond demo quality.

## Requirements

1. Merge PR #374 (resolve review, rebase on current development).
2. **In-proc serving path**: a kernel-facing API to enumerate/serve tools from `McpToolRegistry` without any transport — the server-side half of the in-process bridge (client half is dart_agent_core `LocalMcpTransport`, see arrrrny/dart_agent_core#2). Registry must implement/adapter onto the `LocalMcpHost` interface defined there.
3. **SSE server hardening** (server counterpart of arrrrny/dart_agent_core#4): Bearer auth middleware, per-token tool allowlists, connection limits, idle timeouts, graceful shutdown, structured error responses.
4. **Lifecycle**: `McpServerPlugin` registered with `ZuraffaEngine` — start/stop tied to engine lifecycle; tool registration/unregistration at runtime without restart.
5. **Tool result discipline**: `McpToolResult` supports content blocks + structured payload + `artifactRef` (ref-only pattern for large bodies) — large results never marshaled through transports.
6. Platform verification: SSE server runs on macOS/iOS/Android hosts (device tools in-proc; SSE for debugging).
7. Docs: "MCP runtime" guide (serve modes: in-proc / stdio / SSE; when to use which).

## Acceptance criteria

- [ ] PR #374 merged to development; `zfa mcp list-tools` works on a fresh scaffold
- [ ] In-proc enumeration+call API integration test (registry → LocalMcpHost adapter)
- [ ] SSE server: auth, allowlist, and shutdown tests green; load test 1k concurrent tool calls
- [ ] `McpToolResult.artifactRef` pattern documented with example
- [ ] Backwards-compat: mcp_demo example app still passes

## Dependencies

- Builds on PR #374 (this repo).
- Pairs with arrrrny/dart_agent_core#2 (client-side transport), arrrrny/dart_agent_core#4 (client-side SSE audit).

---
Part of the ZikZak AI agent architecture — `docs/architecture/zikzak-ai-agent-architecture.md` in arrrrny/zik_zak (§3.1, §3.2).

## Comments

**arrrrny** (owner, none):
MAESTRO: https://github.com/arrrrny/zik_zak/issues/176

Unblocks: arrrrny/zuraffa#385 + #386, arrrrny/raptorr#126 (protocol twin)
