# Tasks: Agent Plugin UI Render

**Input**: Design documents from `/specs/023-agent-plugin-ui-render/` (spec.md, plan.md)

**Prerequisites**: plan.md (required), spec.md (required for user stories).

**Tests**: All implementation tasks include paired test tasks (test-first). Tests live under `test/agent/ui_render/`.

**Organization**: Tasks grouped by phase. MVP-critical tasks prefixed `[MVP]`. Each phase delivers an independently testable increment.

## Path Conventions

- Single project (pure-Dart `zuraffa` package).
- Source: `lib/src/agent/ui_render/...`
- Tests: `test/agent/ui_render/...`
- Public exports via `lib/zuraffa.dart`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project structure initialization + public barrel export.

- [ ] T001 [MVP] Create `lib/src/agent/ui_render/` directory
- [ ] T002 [MVP] Create `lib/src/agent/ui_render/ui_render.dart` barrel file
- [ ] T003 [MVP] Export the barrel from `lib/zuraffa.dart`

---

## Phase 2: Foundational Data Types

**Purpose**: Core types that every other component depends on.

- [ ] T004 [MVP] Implement `UiVocabularySchema` (`lib/src/agent/ui_render/ui_vocabulary_schema.dart`) — allowed node types, allowed style tokens, node cap; `validate(tree)` returns `ValidationResult`
- [ ] T005 [MVP] Implement `RenderedView` (`lib/src/agent/ui_render/rendered_view.dart`) — view id + tree + schema version + content hash
- [ ] T006 [MVP] Implement `SemanticAction` (`lib/src/agent/ui_render/semantic_action.dart`) — action id + args + tier (safe/confirm)
- [ ] T007 [MVP] Implement `UiRenderEvent` sealed type (`lib/src/agent/ui_render/ui_render_event.dart`) — render / replace / interaction / policy / done / error
- [ ] T008 Implement `MissionTraceRecorder` (`lib/src/agent/ui_render/mission_trace_recorder.dart`) — stores rendered trees with schemaVersion + contentHash

---

## Phase 3: Render Tool + Event Channel (US1 — P1) 🎯 MVP

**Goal**: Agent calls `ui.render` and the tree renders on the user's device.

**Independent Test**: Render a simple tree; assert the event channel receives a `UiRenderEvent.render` event and the tool returns a view id.

### Tests for User Story 1 (test-first)

- [ ] T009 [MVP] [P] [US1] Write `ui_render_tool_accepts_valid_tree_returns_view_id` in `test/agent/ui_render/ui_render_tool_test.dart`
- [ ] T010 [MVP] [P] [US1] Write `replace_view_id_replaces_existing_view` in `test/agent/ui_render/ui_render_tool_test.dart`
- [ ] T011 [MVP] [P] [US1] Write `ui_event_channel_progressive_rendering` in `test/agent/ui_render/ui_event_channel_test.dart`

### Implementation for User Story 1

- [ ] T012 [MVP] [US1] Implement `UiEventChannel` (`lib/src/agent/ui_render/ui_event_channel.dart`) — `Stream<UiRenderEvent>`, supports progressive partial-tree events
- [ ] T013 [MVP] [US1] Implement `UiRenderTool` (`lib/src/agent/ui_render/ui_render_tool.dart`) — accepts tree + optional `replaceViewId` + optional `hint`; calls `schema.validate`; records trace; emits stream events; returns view id

**Checkpoint**: Agent can render a tree, replace it, and partial trees stream progressively.

---

## Phase 4: Validation + Typed Errors (US3 — P2)

**Goal**: Invalid trees (unknown node / bad token / cap overflow / empty) are rejected with typed errors.

### Tests for User Story 3 (test-first)

- [ ] T014 [MVP] [P] [US3] Write `ui_render_tool_rejects_unknown_node_type` in `test/agent/ui_render/ui_render_tool_test.dart`
- [ ] T015 [MVP] [P] [US3] Write `ui_render_tool_rejects_bad_token` in `test/agent/ui_render/ui_render_tool_test.dart`
- [ ] T016 [MVP] [P] [US3] Write `ui_render_tool_rejects_cap_overflow` in `test/agent/ui_render/ui_render_tool_test.dart`
- [ ] T017 [P] [US3] Write `empty_tree_rejected` in `test/agent/ui_render/ui_vocabulary_schema_test.dart`

### Implementation for User Story 3

- [ ] T018 [MVP] [US3] Wire `UiVocabularySchema.validate` into `UiRenderTool.render`; throw `UiRenderValidationException` with a `ValidationResult` payload describing the exact failure (unknown node / bad token / cap overflow / empty)

**Checkpoint**: Every invalid tree is rejected with a descriptive, retryable error.

---

## Phase 5: Interaction Loop (US2 — P1) 🎯 MVP

**Goal**: User taps an action; the action routes back to the agent.

### Tests for User Story 2 (test-first)

- [ ] T019 [MVP] [P] [US2] Write `semantic_action_routed_to_agent` in `test/agent/ui_render/semantic_action_test.dart`

### Implementation for User Story 2

- [ ] T020 [MVP] [US2] Implement `ActionRouter` interface (delivers `SemanticAction` to the agent as tool result / steering message) — wire into `UiEventChannel.emitInteraction`

**Checkpoint**: Interaction→agent delivery loop closes.

---

## Phase 6: Vocabulary Narrowing (US4 — P2)

**Goal**: Listing-type mission restricts the agent to card variants only.

### Tests for User Story 4 (test-first)

- [ ] T021 [P] [US4] Write `vocabulary_narrowing_restricts_tool_schema` in `test/agent/ui_render/vocabulary_narrowing_test.dart`
- [ ] T022 [P] [US4] Write `vocabulary_narrowing_rejects_out_of_subset_node` in `test/agent/ui_render/vocabulary_narrowing_test.dart`

### Implementation for User Story 4

- [ ] T023 [US4] Implement `vocabularyNarrowing(missionType, baseSchema)` (`lib/src/agent/ui_render/vocabulary_narrowing.dart`) returning a `UiVocabularySchema` subset; wire into `UiRenderTool` so a mission-bound tool validates against the narrowed schema

**Checkpoint**: Constrained missions emit zero out-of-subset components (SC-004).

---

## Phase 7: Policy Gate (US5 — P2)

**Goal**: confirm-tier actions blocked until user approves.

### Tests for User Story 5 (test-first)

- [ ] T024 [P] [US5] Write `policy_gate_blocks_confirm_tier_until_approved` in `test/agent/ui_render/policy_gate_test.dart`
- [ ] T025 [P] [US5] Write `policy_gate_allows_confirm_tier_after_approval` in `test/agent/ui_render/policy_gate_test.dart`

### Implementation for User Story 5

- [ ] T026 [US5] Implement `PolicyGate` (`lib/src/agent/ui_render/policy_gate.dart`) — `intercept(action)` returns a `Future<SemanticAction>` that completes on `approve`/`deny`; on deny the action is dropped and a `policyDenied` event is emitted

**Checkpoint**: Risky actions gated (SC safety contract).

---

## Phase 8: Host Chrome Coexistence + Mission Trace (US6 — P3)

**Goal**: Rendered views coexist with host chrome; mission trace records rendered trees with schema version + content hash.

### Tests for User Story 6 (test-first)

- [ ] T027 [P] [US6] Write `rendered_view_coexists_with_host_chrome` in `test/agent/ui_render/rendered_view_test.dart`
- [ ] T028 [P] [US6] Write `mission_trace_records_rendered_tree_with_schema_version_and_hash` in `test/agent/ui_render/mission_trace_recorder_test.dart`

### Implementation for User Story 6

- [ ] T029 [US6] Add `RenderSlot` contract to `RenderedView` so the host chrome knows where to mount the rendered tree (no overlap with app navigation/sheets/tab bars)
- [ ] T030 [US6] Implement `MissionTraceRecorder.record(view)` storing `{viewId, schemaVersion, contentHash, tree, timestamp}`; expose `replay(viewId)` and `inspect()`

**Checkpoint**: Rendered trees persist into the mission trace with audit metadata (FR-008).

---

## Phase 9: Edge Cases + Verification

**Goal**: Cover edge-case scenarios from spec.

### Tests for Edge Cases (test-first)

- [ ] T031 [P] [Edge] Write `no_active_mission_error` in `test/agent/ui_render/ui_render_tool_test.dart`
- [ ] T032 [P] [Edge] Write `replace_view_id_unknown_returns_view_not_found` in `test/agent/ui_render/ui_render_tool_test.dart`
- [ ] T033 [P] [Edge] Write `rapid_render_calls_last_wins` in `test/agent/ui_render/ui_render_tool_test.dart`

### Implementation for Edge Cases

- [ ] T034 [Edge] Wire `UiRenderTool` to an `activeMission` state — throw `NoActiveMissionException` when null
- [ ] T035 [Edge] Throw `ViewNotFoundException` when `replaceViewId` does not match any known view
- [ ] T036 [Edge] Last-write-wins semantics for rapid `render` calls (earlier calls return `rendered: true` but content is superseded)

---

## Phase 10: Quality Gates

- [ ] T037 [MVP] Run `dart analyze` clean on new code
- [ ] T038 [MVP] Run `dart test test/agent/ui_render/` green
- [ ] T039 Write `tdd/verification.md` with test-first evidence + SC coverage matrix
- [ ] T040 Commit + push branch + open PR
