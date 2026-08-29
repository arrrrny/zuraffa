# Bug Assessment: mcp: land PR #374 and productionize the app-side MCP runtime (in-proc serving, SSE hardening, lifecycle)

- **Slug**: mcp-runtime-productionize
- **Created**: 2026-08-29T03:13:16Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/384
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

This issue tracks landing PR #374 (`feat/369-mcp-plugin-expose-app-features-as-mcp-tools`) onto `development` and productionizing the app-side MCP runtime beyond demo quality. PR #374 adds `McpTool`/`McpToolRegistry` runtime, `McpSseServer` (HTTP+SSE, Bearer), an `McpPlugin` codegen scaffolder, and `zfa mcp serve/list-tools` CLI (82 tests). Requirements: (1) merge PR #374; (2) in-proc serving path via a kernel-facing API + `LocalMcpHost` adapter (pairs with arrrrny/dart_agent_core#2); (3) SSE server hardening — Bearer auth, per-token allowlists, connection limits, idle timeouts, graceful shutdown, structured errors (pairs with arrrrny/dart_agent_core#4); (4) lifecycle — `McpServerPlugin` registered with `ZuraffaEngine`; (5) tool result discipline with `McpToolResult.artifactRef` ref-only pattern; (6) platform verification macOS/iOS/Android; (7) MCP runtime docs. Acceptance criteria list merge, in-proc integration test, SSE auth/allowlist/shutdown + 1k load test, artifactRef docs, and mcp_demo backwards-compat.

See issue: https://github.com/arrrrny/zuraffa/issues/384

## Symptom

The app-side MCP runtime shipped in PR #374 is at demo quality; it is not yet merged to `development` nor productionized (no in-proc serving, SSE hardening, or engine lifecycle integration). This blocks ZikZak AI agent architecture rollout.

## Reproduction

[NEEDS CLARIFICATION — steps depend on which acceptance criterion is being reproduced; see issue body for the per-requirement checklist.]

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed.]

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.
- Pairs with external work in arrrrny/dart_agent_core (#2 client transport, #4 client SSE audit) and arrrrny/raptorr#126; unblocks arrrrny/zuraffa#385 + #386.
- MAESTRO tracking issue: arrrrny/zik_zak#176.

## Open Questions

- [NEEDS CLARIFICATION: which acceptance criterion is the immediate work target?]
- [NEEDS CLARIFICATION: is PR #374 already merged, or is this still pre-merge?]
