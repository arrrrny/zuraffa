# RED Evidence — Agent Runtime Plugin

**Captured**: 2026-08-28, during TDD cycle. Tests were authored against the
spec's FRs/SCs before / alongside the implementation. The initial
`dart test test/agent/runtime/` run produced 2 RED failures documented
below. All other tests passed on first run.

## Failure 1 — `namespace collision prevents silent overwrite (FR-012, SC-002)`

**Symptom**: The test expected a `NamespaceCollisionException` to be thrown
when an SPI provider (namespace `device`) and a remote server (id `device`)
both registered a tool named `scan`. But no exception was thrown — both
tools coexisted in the registry under different canonical names
(`device.scan` vs `remote:device.scan`).

**Root cause**: Test design flaw — my `RemoteMcpServer` always uses
`remote:<id>` as the namespace prefix, so remote tools can never collide
with SPI tools of the same bare name. The collision test must use two
sources that share a namespace.

**Fix**: Replaced the test with one that registers two `_DeviceProvider`
SPI instances (same namespace `device`, same tools `scan` / `extract`).
The second registration throws `NamespaceCollisionException` as expected
(FR-012 — silent overwrite is prevented).

## Failure 2 — Test helpers used `implements` instead of `extends`

**Symptom**: Analyzer errors: `Missing concrete implementation of
'getter McpTool.manifest'` and `Missing concrete implementations of
'AgentHook.afterToolCall', 'AgentHook.beforeToolCall', 'AgentHook.onMissionEnd'`.

**Root cause**: `_FakeTool implements McpTool` and `_OrderHook implements
AgentHook`. Dart's `implements` requires every member (including
default-implemented ones) to be re-declared. The interfaces had sensible
defaults (`manifest` returns a map; the hook methods are no-ops), but
`implements` bypasses defaults.

**Fix**: Switched `_FakeTool` to `extends McpTool` and `_OrderHook` to
`extends AgentHook` so the default implementations are inherited.

## GREEN state

After the fixes, all 20 tests in `test/agent/runtime/` pass:

```
dart test test/agent/runtime/
00:00 +20: All tests passed!
```
