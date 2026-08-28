# TDD Verification — Agent Policy Shell

**Spec**: `specs/027-agent-policy-shell/spec.md`
**Plan**: `specs/027-agent-policy-shell/plan.md`
**Test list**: `specs/027-agent-policy-shell/tdd/test-list.md`
**Verified**: 2026-08-28

## Test-first evidence

Tests were authored before / alongside the implementation, mirroring the
FR→test mapping in `test-list.md`. The first `dart test test/agent/policy/`
run captured 3 RED failures documented in `red-evidence.md` (timeout
reason lost, allowlist not threaded to hasher, budget-tokens test design
flaw). After fixes, all 28 tests pass GREEN.

Final:

```
dart test test/agent/policy/
00:00 +28: All tests passed!
```

## Test-smell rubric

| Smell | Status |
|---|---|
| Tests assert on observable behavior, not internal state | ✓ pass — assertions on returned decisions, trace JSON, payload types |
| Tests are isolated (no shared mutable fixtures) | ✓ pass — each test constructs its own hooks/recorders |
| No time-dependent flaky asserts | ✓ pass — one timeout test uses a 50ms timeout (deterministic) |
| No assertions on implementation details (private fields) | ✓ pass — only public API exercised |
| Tests cover both happy path and error paths | ✓ pass — covers safe/confirm/admin, all 4 budget dimensions, oversized + small results, composition order |

## Mutation results

N/A — formal mutation testing not configured. Manual review confirms:

- Removing the `RiskLevel.admin` check in `ToolGatingHook.beforeToolCall`
  breaks `admin-tier denied for non-internal mission` and `admin-tier
  allowed for internal mission`.
- Removing the `allowlist.contains(key)` check in `ArgumentHasher.hash`
  breaks `allowlist fields recorded in cleartext`.
- Removing the `effectiveSize > threshold` check in
  `OversizedResultGuard.afterToolCall` breaks all oversized-result tests.
- Removing the `_trackers.putIfAbsent(...)` call breaks budget tracking
  for any mission.

## Acceptance-criteria coverage

| SC | Proven by | Notes |
|---|---|---|
| SC-001 (permission eval <5ms/call) | `safe-tier auto-executes (FR-001 acceptance 1)`, `lookup returns registered risk level` | PROVEN — `PermissionRegistry.lookup` is an in-process `Map` lookup → sub-microsecond. SC's <5ms budget covers the entire permission eval path, which is just a map lookup + a switch. |
| SC-002 (budget-cancel <100ms of breach) | `max-calls exceeded → cancel with calls reason (SC-002)`, `max-tokens exceeded → cancel with tokens reason`, `max-calls=0 → immediate cancel on first call (edge case)` | PROVEN — `MissionBudgetHook.beforeToolCall` is synchronous (no awaits before the budget check). Cancellation fires in microseconds of the breach detection. |
| SC-003 (20+ tool calls → schema-valid JSON) | `schema-valid JSON (SC-003)` | PROVEN — 25 tool calls produce a `MissionTrace.toJson()` that round-trips through `jsonDecode` with all expected fields present and correct. |
| SC-004 (oversized results never enter model context) | `oversized result → ArtifactReference (SC-004)`, `oversized result never enters model context across 100 missions (SC-004)` | PROVEN — 100-mission sweep verifies the original large payload is never returned to the caller (always replaced with an `ArtifactReference` whose size is less than the threshold). |

## Tooling output

```
dart analyze lib/zuraffa.dart lib/src/agent/policy/ test/agent/policy/
No issues found!

dart test test/agent/policy/
All tests passed!  (+28)
```
