# RED Evidence — Agent Kernel Mission

**Captured**: 2026-08-28, during TDD cycle. Tests were authored against the
spec's FRs/SCs before / alongside the implementation. The initial `dart test
test/agent/kernel/` run (before fixing the cancel-vs-submit microtask race)
produced 3 RED failures documented below. All other tests passed on first
run.

## Failure 1 — `mid-exec cancel salvages partials as cancelled_partial`

**Symptom**: `expect(missionOutcome, isA<OutcomeCancelledPartial>())` failed
because `await kernel.submit(mission)` returned `OutcomeCompleted` (the
executor's return value) instead of the salvaged `OutcomeCancelledPartial`.

**Root cause**: Microtask-ordering race between `cancel()` and `submit()`. On
`_settled.complete()`, the executor's listener (registered first via
`await cancelToken.onSettled`) fires before `cancel()`'s listener (registered
later via `await runCancellation(...)`). The executor returned
`OutcomeCompleted` and `submit()` called `group.complete(OutcomeCompleted)`
before `cancel()` could call `group.complete(salvagedOutcome)`.

**Fix**: Restructured `cancel()` to salvage + complete the group
**synchronously** before triggering the disposal race. This ensures
`group.isCompleted == true` by the time `submit()` resumes after the executor
returns; `submit()` then returns `group.mission.outcome` (salvaged) instead
of the executor's outcome.

## Failure 2 — `original cancel does NOT cancel subscribers (FR-003)`

**Symptom**: Same root cause as Failure 1 — the subscriber's `submit()` future
returned `OutcomeCompleted` instead of the salvaged `OutcomeCancelledPartial`
because the executor returned first and `group.complete()` was called with
`OutcomeCompleted`.

**Fix**: Same as Failure 1.

## Failure 3 — `post-cancellation zero-leak assertion (FR-006)`

**Symptom**: Same root cause as Failure 1 — `kernel.activeGroups` was empty
after `cancel()` completed because the executor had returned and `submit()`'s
`finally` block removed the group before `cancel()` could salvage.

**Fix**: Same as Failure 1 — completing the group synchronously in `cancel()`
ensures the salvage + completion happens before the executor unblocks.

## GREEN state

After the fix, all 26 tests in `test/agent/kernel/` pass:

```
dart test test/agent/kernel/
00:00 +26: All tests passed!
```
