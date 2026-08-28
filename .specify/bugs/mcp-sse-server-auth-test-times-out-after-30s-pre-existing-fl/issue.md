# Bug Issue: MCP SSE Server: Auth test times out after 30s (pre-existing flaky)

- **Slug**: mcp-sse-server-auth-test-times-out-after-30s-pre-existing-fl
- **Fetched**: 2026-08-27T14:26:39.809270+00:00
- **Issue**: 502
- **URL**: https://github.com/arrrrny/zuraffa/issues/502
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

# Bug Assessment: MCP SSE Server Test Timeout (Pre-existing)

**Slug**: `007-zuraffa-v5-foundation-mcp-sse-timeout`  
**Feature**: `007-zuraffa-v5-foundation`  
**Severity**: Low (Pre-existing, not v5 regression)  
**Status**: Open

---

## Summary

The test `test/plugins/mcp/mcp_sse_server_test.dart` - "McpSseServer remote requests get 401 when Authorization is missing or invalid" times out after 30 seconds. This is a pre-existing flaky test documented in the TDD profile, not a v5 foundation regression.

---

## Root Cause

The test creates an authenticated MCP SSE server and makes a remote request without authorization. The server appears to hang instead of returning a 401 response, causing a timeout.

---

## Expected Behavior

Server should return 401 Unauthorized within a reasonable time.

---

## Actual Behavior

Test times out after 30 seconds waiting for response.

---

## Impact

- Blocks full test suite from passing cleanly
- Masks potential real regressions in test output

---

## Test Case

**File**: `test/plugins/mcp/mcp_sse_server_test.dart`  
**Test**: "McpSseServer remote requests get 401 when Authorization is missing or invalid" (line ~?)

---

## Related to v5 Foundation

No - this is a pre-existing issue unrelated to v5 foundation changes.

---

## Recommendation

1. Investigate and fix the MCP SSE server auth handling
2. Or mark test as `@Timeout(Duration(minutes: 1))` or similar if it's a slow but valid test
3. Or gate behind an integration tag if it requires external dependencies

## Comments

None.
