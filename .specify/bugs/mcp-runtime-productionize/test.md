# Bug Test: mcp: land PR #374 and productionize the app-side MCP runtime

- **Slug**: mcp-runtime-productionize
- **Issue**: https://github.com/arrrrny/zuraffa/issues/384
- **Branch**: fix/mcp-runtime-productionize (off `development`)
- **Result**: verified

## What was verified

Re-ran the reproduction surface (the MCP runtime suite) against the fix on
`fix/mcp-runtime-productionize`. New behavior is covered by targeted tests;
existing behavior is unchanged.

### New tests (all green)

- `mcp_tool_result_test.dart`
  - ok result serialises `artifactRef` when set
  - ok result omits `artifactRef` when null
  - `artifact` factory carries only the ref + summary text
  - error result can carry an `artifactRef`
- `mcp_local_host_test.dart`
  - `McpToolRegistry.call` invokes a registered tool and returns its result
  - `call` returns an error result for an unknown tool (never throws)
  - `call` converts handler throws into tool-level error results
  - `LocalMcpHost.listTools` mirrors registry definitions
  - `LocalMcpHost.callTool` invokes the tool without any transport
- `mcp_sse_server_test.dart`
  - `tools/call` for a tool outside the token allowlist is rejected (-32000)
  - connection limit rejects new SSE streams with 503
  - `stop()` shuts down gracefully (isRunning false, port released)

### Regression surface

- `dart test test/plugins/mcp/` — **116 passed** (104 baseline + 12 new).
  No existing MCP test regressed.

### Static analysis

- `dart analyze` on changed `lib/` and `test/` files — **no issues**.

## Risks / notes

- PR #374 already merged to `development`; this branch is cut from
  `development`, so the diff is only the productionization changes above.
- Changes are additive (new optional constructor params / fields), so the
  `mcp_demo` example and any host app using `McpServerPlugin`/`McpToolResult`
  remain source-compatible without edits.
- Idle-timeout, external `LocalMcpHost` interface alignment, and iOS/Android
  platform verification remain open and are tracked in #384 (deferred to
  follow-up PRs — see `fix.md`).
