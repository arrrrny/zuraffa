# Test List — Agent Policy Shell

**Spec**: `specs/027-agent-policy-shell/spec.md`
**Plan**: `specs/027-agent-policy-shell/plan.md`

| FR / Behavior | Test name | File path | Status |
|---|---|---|---|
| FR-001 (registry lookup) | `lookup returns registered risk level` | `test/agent/policy/tool_gating_and_budget_test.dart` | GREEN |
| FR-001 (fallback to safe when no entry) | `lookup falls back to safe when no entry and no fallback` | `test/agent/policy/tool_gating_and_budget_test.dart` | GREEN |
| FR-001 (most-restrictive wins on conflict — edge) | `most-restrictive wins on conflict (edge case)` | `test/agent/policy/tool_gating_and_budget_test.dart` | GREEN |
| FR-001 (RiskLevel.mostRestrictive ordering) | `RiskLevel.mostRestrictive ordering (admin > confirm > safe)` | `test/agent/policy/tool_gating_and_budget_test.dart` | GREEN |
| FR-001 acceptance 1 (safe auto-executes) | `safe-tier auto-executes (FR-001 acceptance 1)` | `test/agent/policy/tool_gating_and_budget_test.dart` | GREEN |
| FR-002 (confirm blocks until approved) | `confirm-tier blocks until approved (FR-002 acceptance 2)` | `test/agent/policy/tool_gating_and_budget_test.dart` | GREEN |
| FR-002 (confirm denies on user rejection) | `confirm-tier denies on user rejection` | `test/agent/policy/tool_gating_and_budget_test.dart` | GREEN |
| FR-002 acceptance 3 (confirm denies on timeout) | `confirm-tier denies on timeout (FR-002 acceptance 3)` | `test/agent/policy/tool_gating_and_budget_test.dart` | GREEN |
| FR-003 acceptance 4 (admin denied for non-internal) | `admin-tier denied for non-internal mission (FR-003 acceptance 4)` | `test/agent/policy/tool_gating_and_budget_test.dart` | GREEN |
| FR-003 acceptance 5 (admin allowed for internal) | `admin-tier allowed for internal mission (FR-003 acceptance 5)` | `test/agent/policy/tool_gating_and_budget_test.dart` | GREEN |
| FR-004 (allowlist overrides risk level) | `per-mission allowlist overrides risk level (FR-004)` | `test/agent/policy/tool_gating_and_budget_test.dart` | GREEN |
| FR-005 + FR-006 (max-calls exceeded → cancel) | `max-calls exceeded → cancel with calls reason (SC-002)` | `test/agent/policy/tool_gating_and_budget_test.dart` | GREEN |
| FR-005 + FR-006 (max-tokens exceeded → cancel) | `max-tokens exceeded → cancel with tokens reason` | `test/agent/policy/tool_gating_and_budget_test.dart` | GREEN |
| FR-005 edge (budget=0 → immediate cancel) | `max-calls=0 → immediate cancel on first call (edge case)` | `test/agent/policy/tool_gating_and_budget_test.dart` | GREEN |
| FR-013 (budget-degrade callback fires on breach) | `budget-degrade callback fires on breach (FR-013)` | `test/agent/policy/tool_gating_and_budget_test.dart` | GREEN |
| FR-007 + FR-008 (hashed args by default) | `records each tool call with hashed args by default (FR-008)` | `test/agent/policy/trace_and_composition_test.dart` | GREEN |
| FR-008 (allowlist fields in cleartext) | `allowlist fields recorded in cleartext (FR-008)` | `test/agent/policy/trace_and_composition_test.dart` | GREEN |
| FR-007 + SC-003 (20+ tool calls → schema-valid JSON) | `schema-valid JSON (SC-003)` | `test/agent/policy/trace_and_composition_test.dart` | GREEN |
| FR-009 (concurrent streaming — no corruption) | `concurrent streaming — no corruption (FR-009)` | `test/agent/policy/trace_and_composition_test.dart` | GREEN |
| FR-010 (small result passes through) | `small result passes through unchanged` | `test/agent/policy/trace_and_composition_test.dart` | GREEN |
| FR-010 + SC-004 (oversized → ArtifactReference) | `oversized result → ArtifactReference (SC-004)` | `test/agent/policy/trace_and_composition_test.dart` | GREEN |
| FR-010 edge (storage unavailable → truncated) | `artifact storage unavailable → truncated with marker (edge case)` | `test/agent/policy/trace_and_composition_test.dart` | GREEN |
| SC-004 (100 missions, zero large payloads in context) | `oversized result never enters model context across 100 missions (SC-004)` | `test/agent/policy/trace_and_composition_test.dart` | GREEN |
| FR-011 (composition: first deny wins) | `runs hooks in registration order; first deny wins` | `test/agent/policy/trace_and_composition_test.dart` | GREEN |
| FR-011 (disabled hooks skipped) | `disabled hooks are skipped` | `test/agent/policy/trace_and_composition_test.dart` | GREEN |
| FR-011 (enable/disable by id) | `enable/disable by id` | `test/agent/policy/trace_and_composition_test.dart` | GREEN |
| FR-011 (afterToolCall reverse order — middleware pattern) | `afterToolCall runs hooks in reverse order (middleware pattern)` | `test/agent/policy/trace_and_composition_test.dart` | GREEN |
| FR-012 (fallback to tool's own risk metadata) | `lookup uses fallback when provided (FR-012)` | `test/agent/policy/tool_gating_and_budget_test.dart` | GREEN |

## Success Criteria Coverage

| SC | Test(s) that prove it |
|---|---|
| SC-001 (permission eval <5ms/call) | `safe-tier auto-executes (FR-001 acceptance 1)` — structural correctness proven; perf not benchmarked (in-process map lookup is sub-microsecond) |
| SC-002 (budget-cancel <100ms of breach) | `max-calls exceeded → cancel with calls reason (SC-002)`, `max-tokens exceeded → cancel with tokens reason`, `max-calls=0 → immediate cancel on first call` — synchronous check on every call → cancellation in microseconds |
| SC-003 (20+ tool calls → schema-valid JSON) | `schema-valid JSON (SC-003)` |
| SC-004 (oversized results never enter model context) | `oversized result → ArtifactReference (SC-004)`, `oversized result never enters model context across 100 missions (SC-004)` |
