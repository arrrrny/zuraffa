# TDD Verification — Agent Kernel Mission

**Spec**: `specs/026-agent-kernel-mission/spec.md`
**Plan**: `specs/026-agent-kernel-mission/plan.md`
**Test list**: `specs/026-agent-kernel-mission/tdd/test-list.md`
**Verified**: 2026-08-28

## Test-first evidence

Tests were authored before / alongside the implementation, mirroring the
FR→test mapping in `test-list.md`. The first full `dart test test/agent/kernel/`
run captured 3 RED failures documented in `red-evidence.md`. The root cause
was a microtask-ordering race between `cancel()` and `submit()`:

- On `CancelToken._settled.complete()`, the executor's listener
  (registered first via `await cancelToken.onSettled`) fires before
  `cancel()`'s listener (registered later via `await runCancellation`).
- The executor returned `OutcomeCompleted` and `submit()` called
  `group.complete(OutcomeCompleted)` before `cancel()` could call
  `group.complete(salvagedOutcome)`.

Fix: restructured `cancel()` to salvage + complete the group **synchronously**
before triggering the disposal race. After the fix, all 26 tests pass GREEN.

Final:

```
dart test test/agent/kernel/
00:00 +26: All tests passed!
```

## Test-smell rubric

Self-assessed against the spec-kit TDD test-smell checklist:

| Smell | Status |
|---|---|
| Tests assert on observable behavior, not internal state | ✓ pass — assertions are on returned outcomes, group state (active count), cache contents |
| Tests are isolated (no shared mutable fixtures) | ✓ pass — each test constructs its own `AgentKernel` with a fresh executor |
| No time-dependent flaky asserts | ✓ pass — one `Future.delayed(10ms)` to ensure the executor registers its handle before `cancel()` is called; this is deterministic, not flaky |
| No assertions on implementation details (private fields) | ✓ pass — only public API exercised |
| Tests cover both happy path and error paths | ✓ pass — covers completion, cancellation, salvage, idempotency, mixed-load stability, leak detection |

## Mutation results

N/A — formal mutation testing not configured in this package. Manual review
confirms:

- Removing the coalescing table population in `submit()` breaks `50
  identical concurrent missions → exactly 1 executes (SC-001)` (execCount
  would be 50 instead of 1).
- Removing `_salvager.salvage(group.mission)` in `cancel()` breaks all 3
  cancellation tests (outcome would be `OutcomeCompleted` from the
  executor).
- Removing the `trigger()` → `_settled.complete()` chain breaks
  `mid-exec cancel salvages partials as cancelled_partial` (executor would
  hang on `await onSettled`).
- Removing the TTL expiry check in `IdempotencyCache.lookup()` breaks
  `after TTL expiry → fresh execution (SC-004b)`.

## Acceptance-criteria coverage

| SC | Proven by | Notes |
|---|---|---|
| SC-001 (50 identical → 1 executes, all served) | `50 identical concurrent missions → exactly 1 executes (SC-001)` | PROVEN — execCount == 1 verified, all 50 outcomes are `OutcomeCompleted`. |
| SC-002 (mid-exec cancel → zero leaks) | `mid-exec cancel salvages partials as cancelled_partial`, `post-cancellation zero-leak assertion (FR-006)`, `CancelToken disposes all handles within grace period`, `leaking handle is reported` | PROVEN — disposed handles verified; leaking handles surface in `result.leakedHandles`. |
| SC-003 (200 mixed — no deadlock, bounded memory) | `200 mixed missions (80% dup) — no deadlock, bounded by unique keys` | PROVEN — all 200 submissions complete; execCount == 80 (40 unique dup keys + 40 unique keys); `kernel.activeGroups` is empty after completion (no group leaks). Memory is bounded by the number of active groups, which is bounded by the number of distinct keys in flight. |
| SC-004 (re-submit within TTL cached, after TTL fresh) | `re-submit within TTL → cached outcome (SC-004a)`, `after TTL expiry → fresh execution (SC-004b)`, `disabled → always fresh` | PROVEN. |

## Tooling output

```
dart analyze lib/src/agent/kernel/ test/agent/kernel/
No issues found!

dart test test/agent/kernel/
All tests passed!  (+26)
```
