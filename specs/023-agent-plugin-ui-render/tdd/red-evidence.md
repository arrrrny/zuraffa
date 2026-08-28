# RED Evidence — Agent Plugin UI Render

**Captured**: 2026-08-28, after tests were written but during implementation debugging (initial run before bug fixes / test timing adjustments).

`dart test test/agent/ui_render/` initial run produced 3 failures (the other 51 tests passed on first run). The failures fell into two categories:

## Test-timing failures (listener microtask ordering)

These tests asserted that an event listener received an event immediately after awaiting the emitting call. The broadcast `StreamController` (default `sync: false`) schedules listener callbacks via microtasks that run later than the await continuation. Fix: add `await Future<void>.delayed(Duration.zero)` after the await to flush microtask delivery.

- `test/agent/ui_render/ui_render_tool_test.dart: UiRenderTool routeInteraction (FR-004 / FR-006) semantic_action_routed_to_agent`
  - Reason: `received.whereType<UiRenderEventInteraction>()` was empty immediately after `await tool.routeInteraction(action)` — listener callback had not yet run.
- `test/agent/ui_render/ui_render_tool_test.dart: UiRenderTool routeInteraction (FR-004 / FR-006) confirm-tier action denied — never reaches the agent`
  - Reason: same — `received.whereType<UiRenderEventPolicy>()` was empty for the same reason.

## Assertion semantics failure (replace semantics)

- `test/agent/ui_render/ui_render_tool_test.dart: UiRenderTool replace_view_id_replaces_existing_view`
  - Reason: asserted `tool.view(firstId)!.isActive == false`, but after a replace the new view shares the same id, so `tool.view(firstId)` returns the new (active) view. Fix: assert the current view carries the new tree (`tool.view(firstId)!.tree == second`), which is the actual semantic the spec calls out ("new tree replaces the previous view content").

After fixes, all 3 tests pass (GREEN).
