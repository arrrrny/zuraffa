# Test List — Agent Kernel Mission

**Spec**: `specs/026-agent-kernel-mission/spec.md`
**Plan**: `specs/026-agent-kernel-mission/plan.md`

Maps each Functional Requirement (FR-001..010) and Success Criteria (SC-001..004) to a concrete test name + file path + status column. Status starts at **RED** (pre-implementation) and is updated to **GREEN** once `dart test` passes that test.

| FR / Behavior | Test name | File path | Status |
|---|---|---|---|
| FR-001 (coalesce identical missions via composite key) | `MissionKey coalesces identical four-tuples` | `test/agent/kernel/mission_test.dart` | GREEN |
| FR-001 (different strategy variant does NOT coalesce) | `MissionKey different strategy variant does NOT coalesce` | `test/agent/kernel/mission_test.dart` | GREEN |
| FR-001 (different country does NOT coalesce) | `MissionKey different country does NOT coalesce` | `test/agent/kernel/mission_test.dart` | GREEN |
| FR-001 (canonical string is deterministic) | `MissionKey canonical string is deterministic and stable` | `test/agent/kernel/mission_test.dart` | GREEN |
| FR-002 (execute once + fan out events to subscribers) | `50 identical concurrent missions → exactly 1 executes (SC-001)` | `test/agent/kernel/agent_kernel_test.dart` | GREEN |
| FR-002 (subscribers receive same outcome) | `50 identical concurrent missions → exactly 1 executes (SC-001)` | `test/agent/kernel/agent_kernel_test.dart` | GREEN |
| FR-003 (cancel original does NOT cancel subscribers) | `original cancel does NOT cancel subscribers (FR-003)` | `test/agent/kernel/agent_kernel_test.dart` | GREEN |
| FR-004 (grace period disposes resources) | `CancelToken disposes all handles within grace period` | `test/agent/kernel/cancellation_idempotency_test.dart` | GREEN |
| FR-004 (mid-exec cancel triggers grace period) | `mid-exec cancel salvages partials as cancelled_partial` | `test/agent/kernel/agent_kernel_test.dart` | GREEN |
| FR-005 (partials salvaged as `cancelled_partial`) | `salvages accumulated partials as cancelled_partial` | `test/agent/kernel/cancellation_idempotency_test.dart` | GREEN |
| FR-005 (empty salvage still `cancelled_partial` — edge case) | `empty salvage still records cancelled_partial (edge case)` | `test/agent/kernel/cancellation_idempotency_test.dart` | GREEN |
| FR-006 (post-cancellation zero-leak assertion) | `post-cancellation zero-leak assertion (FR-006)` | `test/agent/kernel/agent_kernel_test.dart` | GREEN |
| FR-006 (leaking handle is reported) | `leaking handle is reported (FR-006 leak assertion)` | `test/agent/kernel/cancellation_idempotency_test.dart` | GREEN |
| FR-007 (re-submit within TTL → cached) | `re-submit within TTL → cached outcome (SC-004a)` | `test/agent/kernel/agent_kernel_test.dart` | GREEN |
| FR-007 (after TTL → fresh) | `after TTL expiry → fresh execution (SC-004b)` | `test/agent/kernel/agent_kernel_test.dart` | GREEN |
| FR-007 (disabled → always fresh) | `disabled → always fresh` | `test/agent/kernel/agent_kernel_test.dart` | GREEN |
| FR-007 (lookup returns null when disabled) | `lookup returns null when disabled` | `test/agent/kernel/cancellation_idempotency_test.dart` | GREEN |
| FR-007 (LRU eviction at maxEntries) | `LRU eviction at maxEntries` | `test/agent/kernel/cancellation_idempotency_test.dart` | GREEN |
| FR-008 (introspection: activeMissions + subscribers) | `reports active missions and subscriber counts` | `test/agent/kernel/agent_kernel_test.dart` | GREEN |
| FR-008 (introspection: coalescing window) | `coalescing window is reported` | `test/agent/kernel/agent_kernel_test.dart` | GREEN |
| FR-009 (single-isolate assumption documented) | — (doc-only; verified in `agent_kernel.dart` library doc) | — | GREEN |
| FR-009 (MissionExecutor extension point) | — (injectable via constructor; verified by all tests using a custom executor) | — | GREEN |
| FR-010 (coalescing window configurable) | `coalescing window is reported` | `test/agent/kernel/agent_kernel_test.dart` | GREEN |
| Mission outcome labels | `MissionOutcome labels match spec` | `test/agent/kernel/mission_test.dart` | GREEN |
| SC-003 (200 mixed missions — no deadlock) | `200 mixed missions (80% dup) — no deadlock, bounded by unique keys` | `test/agent/kernel/agent_kernel_test.dart` | GREEN |

## Success Criteria Coverage

| SC | Test(s) that prove it |
|---|---|
| SC-001 (50 identical → 1 executes, all served) | `50 identical concurrent missions → exactly 1 executes (SC-001)` |
| SC-002 (mid-exec cancel → zero leaks) | `mid-exec cancel salvages partials as cancelled_partial`, `post-cancellation zero-leak assertion (FR-006)`, `CancelToken disposes all handles within grace period` |
| SC-003 (200 mixed — no deadlock, bounded memory) | `200 mixed missions (80% dup) — no deadlock, bounded by unique keys` |
| SC-004 (re-submit within TTL cached, after TTL fresh) | `re-submit within TTL → cached outcome (SC-004a)`, `after TTL expiry → fresh execution (SC-004b)` |
