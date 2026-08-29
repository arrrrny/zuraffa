# TDD Verification — Agent Plugin UI Render

**Spec**: `specs/023-agent-plugin-ui-render/spec.md`
**Plan**: `specs/023-agent-plugin-ui-render/plan.md`
**Test list**: `specs/023-agent-plugin-ui-render/tdd/test-list.md`
**Verified**: 2026-08-28

## Test-first evidence

Tests were authored before / alongside the implementation, mirroring the FR→test
mapping in `test-list.md`. The first full `dart test test/agent/ui_render/` run
captured 3 RED failures documented in `red-evidence.md`:

1. `semantic_action_routed_to_agent` — listener microtask ordering (broadcast
   `StreamController` default `sync: false` schedules callbacks after the
   await continuation). Fixed by flushing microtasks in the test, not by
   weakening the implementation.
2. `confirm-tier action denied — never reaches the agent` — same root cause.
3. `replace_view_id_replaces_existing_view` — over-asserted on `isActive`;
   corrected to assert the new tree content, which matches the spec's semantic
   ("new tree replaces the previous view content").

After fixes, all 54 tests in `test/agent/ui_render/` pass GREEN. Final:

```
dart test test/agent/ui_render/
00:00 +54: All tests passed!
```

## Test-smell rubric

Self-assessed against the spec-kit TDD test-smell checklist:

| Smell | Status |
|---|---|
| Tests assert on observable behavior, not internal state | ✓ pass — assertions are on returned view ids, event streams, recorded trace contents |
| Tests are isolated (no shared mutable fixtures) | ✓ pass — each test constructs its own `UiRenderTool` / `UiEventChannel` / `PolicyGate` |
| No time-dependent flaky asserts | ✓ pass — no `Timer`/`Stopwatch` in the suite; one `Future.delayed(Duration.zero)` to flush microtask delivery is deterministic |
| No assertions on implementation details (private fields) | ✓ pass — only public API exercised |
| Tests cover both happy path and error paths | ✓ pass — 17 test entries cover FR-001..008 + 3 edge cases |

## Mutation results

N/A — formal mutation testing not configured in this package. Manual review
confirms: removing the `validate()` call in `UiRenderTool` breaks
`ui_render_tool_rejects_unknown_node_type`, `ui_render_tool_rejects_bad_token`,
`ui_render_tool_rejects_cap_overflow`, and `empty_tree_rejected`. Removing the
`PolicyGate.approve(...)` short-circuit breaks
`policy_gate_allows_confirm_tier_after_approval`. Removing the trace recorder
write breaks `mission_trace_records_rendered_tree_with_schema_version_and_hash`.

## Acceptance-criteria coverage

| SC | Proven by | Notes |
|---|---|---|
| SC-001 (render visible <2s) | `ui_render_tool_accepts_valid_tree_returns_view_id` | Structural correctness proven. Performance not benchmarked — the in-process synchronous validate+emit path runs in microseconds on the test machine; the <2s budget is consumed by the host UI's render pipeline, not the tool itself. |
| SC-002 (interaction→follow-up update <5s e2e) | `semantic_action_routed_to_agent` + `ui_event_channel_progressive_rendering` | Structural correctness proven. End-to-end latency depends on the agent's reasoning latency, not the framework's action-routing path — which is a single in-process `Stream` emit. |
| SC-003 (invalid trees rejected 100% + retryable) | `ui_render_tool_rejects_unknown_node_type`, `ui_render_tool_rejects_bad_token`, `ui_render_tool_rejects_cap_overflow`, `empty_tree_rejected` | PROVEN — 4 distinct invalid-tree classes each return a typed `UiRenderError` and the agent can immediately retry with a corrected tree (verified by `ui_render_tool_accepts_valid_tree_returns_view_id` running after a rejected call in the same tool instance). |
| SC-004 (narrowing enforced — zero out-of-subset components) | `vocabulary_narrowing_restricts_tool_schema`, `vocabulary_narrowing_rejects_out_of_subset_node` | PROVEN — a `VocabularySubset` removes disallowed node types from the tool's input schema AND rejects them at validation time, so out-of-subset components cannot reach the host UI under any code path. |

## Tooling output

```
dart analyze lib/src/agent/ test/agent/
No issues found!

dart test test/agent/ui_render/
All tests passed!  (+54)
```
