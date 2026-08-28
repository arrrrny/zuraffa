# TDD Verification — Agent Runtime Plugin

**Spec**: `specs/028-agent-runtime-plugin/spec.md`
**Plan**: `specs/028-agent-runtime-plugin/plan.md`
**Test list**: `specs/028-agent-runtime-plugin/tdd/test-list.md`
**Verified**: 2026-08-28

## Test-first evidence

Tests were authored before / alongside the implementation, mirroring the
FR→test mapping in `test-list.md`. The first `dart test test/agent/runtime/`
run captured 2 RED failures documented in `red-evidence.md` (test design
flaw on collision + `implements` vs `extends` on test helpers). After
fixes, all 20 tests pass GREEN.

Final:

```
dart test test/agent/runtime/
00:00 +20: All tests passed!
```

## Test-smell rubric

| Smell | Status |
|---|---|
| Tests assert on observable behavior, not internal state | ✓ pass — assertions on returned events, registry contents, kernel status |
| Tests are isolated (no shared mutable fixtures) | ✓ pass — each test constructs its own plugin/kernel |
| No time-dependent flaky asserts | ✓ pass — no `Timer`/`Stopwatch` in the suite |
| No assertions on implementation details (private fields) | ✓ pass — only public API exercised |
| Tests cover both happy path and error paths | ✓ pass — covers assembly, collision, delegation, fallback LLM, persistence, hooks, status |

## Mutation results

N/A — formal mutation testing not configured. Manual review confirms:

- Removing the `_tools.containsKey(canonical)` check in
  `McpToolRegistry.register` breaks both collision tests.
- Removing the `await for (final event in statefulAgent.runStream(mission))`
  delegation breaks `3-tool mission streams typed events (SC-001)`.
- Removing the `try { primary.complete(prompt) } catch (_) {}` block in
  `FallbackLLMClient.complete` breaks `falls back to secondary on primary
  failure`.
- Removing the `_stateStorage.save(state)` call breaks session-state
  persistence on mission start.

## Acceptance-criteria coverage

| SC | Proven by | Notes |
|---|---|---|
| SC-001 (3-tool mission with SPI + usecase, streams typed events, zero loop duplication) | `3-tool mission streams typed events (SC-001)`, `zero agent-loop duplication (FR-013)` | PROVEN — `_DeviceProvider` (SPI) contributes 2 tools, `_FakeTool('usecase_tool')` contributes 1 usecase tool → 3-tool mission. Events stream from the kernel via `StatefulAgent.runStream`; `StubStatefulAgent.callCount == 1` proves no internal loop. |
| SC-002 (remote SSE tools merged + collision prevented) | `remote SSE tools merged with collision prevention (SC-002)`, `namespace collision prevents silent overwrite (FR-012, SC-002)` | PROVEN — remote tools appear in the registry under `remote:<id>.<toolName>` alongside in-proc SPI tools. Collision between same-namespace same-name tools throws `NamespaceCollisionException` (no silent overwrite). |
| SC-003 (test McpToolProvider discovered via DI) | `buildTools returns tools under a namespace`, `DI context passes dependencies to providers (FR-002)` | PROVEN — `_DeviceProvider` is passed via constructor (DI); `McpToolContext.dependency('dep')` returns the registered instance. |
| SC-004 (kernel.status() accurate) | `reports providers, tool counts, and remote health` | PROVEN — status returns: providers map (namespace → class name), toolCountPerNamespace (e.g. `{device: 2, remote:sse1: 1}`), remoteServerHealth (e.g. `{sse1: healthy}`), totalToolCount (3). |

## Tooling output

```
dart analyze lib/zuraffa.dart lib/src/agent/runtime/ test/agent/runtime/
No issues found!

dart test test/agent/runtime/
All tests passed!  (+20)
```
