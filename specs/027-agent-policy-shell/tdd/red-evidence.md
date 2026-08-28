# RED Evidence — Agent Policy Shell

**Captured**: 2026-08-28, during TDD cycle. Tests were authored against the
spec's FRs/SCs before / alongside the implementation. The initial
`dart test test/agent/policy/` run produced 3 RED failures documented below.
All other tests passed on first run.

## Failure 1 — `confirm-tier denies on timeout (FR-002 acceptance 3)`

**Symptom**: `expect((decision as HookDecisionDeny).reason, contains('timed out'))`
failed because the reason was `'user denied confirm-tier tool "confirm_tool"'`
instead of `'confirm-tier tool "confirm_tool" timed out'`.

**Root cause**: I used `approvalCallback(prompt).timeout(confirmTimeout, onTimeout: () => false)`
which silently returns `false` on timeout, falling into the `if (!approved)`
branch that returns the "user denied" reason — losing the typed
"timed out" signal the spec requires (FR-002 acceptance 3).

**Fix**: Use the throwing form of `.timeout()` (no `onTimeout` callback) so
the `TimeoutException` is caught and the explicit "timed out" denial reason
is returned.

## Failure 2 — `allowlist fields recorded in cleartext (FR-008)`

**Symptom**: `expect(record.cleartextArgs['public'], equals('visible'))` failed
because the actual value was `'__hashed__:360eba3dea9d2744'`.

**Root cause**: `MissionTraceRecorder` constructed its `ArgumentHasher` without
passing the `allowlist` set, so all fields were hashed by default.

**Fix**: Pass `allowlist` to the hasher in the `MissionTraceRecorder`
constructor: `ArgumentHasher(allowlist: allowlist)`.

## Failure 3 — `max-tokens exceeded → cancel with tokens reason`

**Symptom**: The test used 50 tokens of a 100-token budget on the first call,
then expected the second `beforeToolCall` to cancel. But `tracker.tokens` (50)
was still below `budget.maxTokens` (100), so the call was allowed.

**Root cause**: Test design — `beforeToolCall` only sees tokens used SO FAR.
For it to detect a breach, the first call must have consumed enough tokens
to reach the limit.

**Fix**: Test now uses 100 tokens on the first call (exactly the budget), so
the second `beforeToolCall` sees `tracker.tokens (100) >= budget.maxTokens (100)`
and returns `HookDecisionCancelMission`. The implementation is unchanged —
the spec is satisfied correctly.

## GREEN state

After the fixes, all 28 tests in `test/agent/policy/` pass:

```
dart test test/agent/policy/
00:00 +28: All tests passed!
```
