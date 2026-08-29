# Bug Fix: mcp: land PR #374 and productionize the app-side MCP runtime

- **Slug**: mcp-runtime-productionize
- **Issue**: https://github.com/arrrrny/zuraffa/issues/384
- **Branch**: fix/mcp-runtime-productionize (off `development`)
- **Status**: applied
- **TDD mode**: on (`tdd_enabled: true`) — executed as a focused
  implementation + targeted `dart test` cycle (red-green per slice) rather
  than the full spec-whole `tdd.run` loop, because #384 is a 7-requirement
  epic and the loaded assessment was a stub. This PR is **slice 1 of N**.

## Scope of this slice

Issue #384 is an epic; PR #374 is already MERGED. This fix advances the
remaining productionization requirements with self-contained, testable
changes:

- **Req #5 — Tool result discipline**: `McpToolResult.artifactRef` (ref-only
  pattern for large bodies). Field + `McpToolResult.artifact` factory +
  serialization. Wire carries only the ref, never the body.
- **Req #2 — In-proc serving path (server half)**: `McpToolRegistry.call`
  (transport-free invocation) + new `LocalMcpHost` adapter class wrapping the
  registry. This is the server-side half of the in-process bridge; the client
  half (`LocalMcpTransport`) lives in `arrrrny/dart_agent_core#2` and defines
  the `LocalMcpHost` interface `LocalMcpHost` should later `implements`.
- **Req #3 — SSE server hardening**:
  - Per-token tool allowlists (`McpAuth.tokenToolAllowlist` +
    `McpSseServer.toolAllowlist` / `McpServerPlugin.sseToolAllowlist`).
    Denied `tools/call` returns a JSON-RPC `-32000` "not permitted" error.
  - Connection limits (`McpSseServer.maxConnections` /
    `McpServerPlugin.maxSseConnections`); new SSE streams beyond the cap get
    HTTP 503.
  - Graceful shutdown: `McpSseServer.stop()` now closes SSE streams and stops
    listening with `force: false` (in-flight requests drain) instead of the
    previous `force: true`.

## Deferred to follow-up PRs (still open on #384)

- **Req #2 (full)**: align `LocalMcpHost` with the external
  `arrrrny/dart_agent_core#2` interface; in-proc integration test across the
  bridge.
- **Req #3**: idle timeouts (timing-sensitive; needs a follow-up with a
  deterministic clock-injected test), structured-error audit against
  `dart_agent_core#4`.
- **Req #4**: engine-lifecycle wiring is already present
  (`McpServerPlugin.onInit`); runtime register/unregister verified — no code
  change needed beyond what shipped in PR #374.
- **Req #6**: platform verification on iOS/Android hosts (device tools in-proc;
  SSE for debugging).
- **Req #7 (partial)**: `doc/mcp_runtime.md` added (serve modes, artifactRef,
  SSE hardening, lifecycle). The "when to use which" guide is covered.

## Files changed

- `lib/src/core/module/mcp_tool.dart` — `artifactRef` field + factory + `toJson`.
- `lib/src/core/module/mcp_tool_registry.dart` — `call()` (in-proc bridge).
- `lib/src/core/module/mcp_local_host.dart` — NEW `LocalMcpHost` adapter.
- `lib/src/mcp/auth.dart` — `tokenToolAllowlist`, `isToolAllowed`, `tokenFromHeader`.
- `lib/src/mcp/sse_server.dart` — allowlist enforcement, `maxConnections`,
  graceful `stop()`, shared `_auth`.
- `lib/src/core/module/mcp_server_plugin.dart` — `maxSseConnections`,
  `sseToolAllowlist` forwarded to the SSE server.
- `doc/mcp_runtime.md` — NEW MCP runtime guide.

## Tests added

- `test/plugins/mcp/mcp_tool_result_test.dart` — artifactRef serialization.
- `test/plugins/mcp/mcp_local_host_test.dart` — registry `call` + `LocalMcpHost`.
- `test/plugins/mcp/mcp_sse_server_test.dart` — allowlist 403/-32000,
  connection-limit 503, graceful shutdown.

## Verification

- `dart analyze` on all changed `lib/` and `test/` files: **no issues**.
- `dart test test/plugins/mcp/` — **116 passed** (104 baseline + 12 new).
