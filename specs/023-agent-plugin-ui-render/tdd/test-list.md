# Test List — Agent Plugin UI Render

**Spec**: `specs/023-agent-plugin-ui-render/spec.md`
**Plan**: `specs/023-agent-plugin-ui-render/plan.md`

Maps each Functional Requirement (FR-001..008) and the edge-case behaviors from the spec to a concrete test name + file path + status column. Status starts at **RED** (pre-implementation) and is updated to **GREEN** once `dart test` passes that test.

| FR / Behavior | Test name | File path | Status |
|---|---|---|---|
| FR-001 (render valid tree → view id) | `ui_render_tool_accepts_valid_tree_returns_view_id` | `test/agent/ui_render/ui_render_tool_test.dart` | GREEN |
| FR-001 acceptance 2 (replace existing view) | `replace_view_id_replaces_existing_view` | `test/agent/ui_render/ui_render_tool_test.dart` | GREEN |
| FR-002 (reject unknown node type) | `ui_render_tool_rejects_unknown_node_type` | `test/agent/ui_render/ui_render_tool_test.dart` | GREEN |
| FR-002 (reject bad token) | `ui_render_tool_rejects_bad_token` | `test/agent/ui_render/ui_render_tool_test.dart` | GREEN |
| FR-002 (reject cap overflow) | `ui_render_tool_rejects_cap_overflow` | `test/agent/ui_render/ui_render_tool_test.dart` | GREEN |
| FR-002 (reject empty tree — edge case) | `empty_tree_rejected` | `test/agent/ui_render/ui_vocabulary_schema_test.dart` | GREEN |
| FR-003 (progressive rendering via event channel) | `ui_event_channel_progressive_rendering` | `test/agent/ui_render/ui_event_channel_test.dart` | GREEN |
| FR-004 (semantic action routed back to agent) | `semantic_action_routed_to_agent` | `test/agent/ui_render/semantic_action_test.dart` | GREEN |
| FR-005 (vocabulary narrowing restricts tool schema) | `vocabulary_narrowing_restricts_tool_schema` | `test/agent/ui_render/vocabulary_narrowing_test.dart` | GREEN |
| FR-005 (reject out-of-subset node under narrowing) | `vocabulary_narrowing_rejects_out_of_subset_node` | `test/agent/ui_render/vocabulary_narrowing_test.dart` | GREEN |
| FR-006 (policy gate blocks confirm-tier until approved) | `policy_gate_blocks_confirm_tier_until_approved` | `test/agent/ui_render/policy_gate_test.dart` | GREEN |
| FR-006 (policy gate allows after approval) | `policy_gate_allows_confirm_tier_after_approval` | `test/agent/ui_render/policy_gate_test.dart` | GREEN |
| FR-007 (rendered view coexists with host chrome) | `rendered_view_coexists_with_host_chrome` | `test/agent/ui_render/rendered_view_test.dart` | GREEN |
| FR-008 (mission trace records tree + schemaVersion + hash) | `mission_trace_records_rendered_tree_with_schema_version_and_hash` | `test/agent/ui_render/mission_trace_recorder_test.dart` | GREEN |
| Edge case — no active mission | `no_active_mission_error` | `test/agent/ui_render/ui_render_tool_test.dart` | GREEN |
| Edge case — replaceViewId unknown | `replace_view_id_unknown_returns_view_not_found` | `test/agent/ui_render/ui_render_tool_test.dart` | GREEN |
| Edge case — rapid render calls last wins | `rapid_render_calls_last_wins` | `test/agent/ui_render/ui_render_tool_test.dart` | GREEN |

## Success Criteria Coverage

| SC | Test(s) that prove it |
|---|---|
| SC-001 (render <2s) | `ui_render_tool_accepts_valid_tree_returns_view_id` (structural correctness; perf not benchmarked) |
| SC-002 (interaction→update <5s e2e) | `semantic_action_routed_to_agent` (structural correctness; perf not benchmarked) |
| SC-003 (invalid trees rejected 100% + retryable) | `ui_render_tool_rejects_unknown_node_type`, `ui_render_tool_rejects_bad_token`, `ui_render_tool_rejects_cap_overflow`, `empty_tree_rejected` |
| SC-004 (narrowing enforced — zero out-of-subset components) | `vocabulary_narrowing_restricts_tool_schema`, `vocabulary_narrowing_rejects_out_of_subset_node` |
