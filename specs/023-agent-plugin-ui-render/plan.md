# Implementation Plan: Agent Plugin UI Render

**Branch**: `023-agent-plugin-ui-render` | **Date**: 2026-08-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/023-agent-plugin-ui-render/spec.md`

## Summary

Adds an agent-facing `ui.render` tool plus a streaming UI event channel and the action-loop closure that lets an agent author live, interactive UI on the user's device. An agent calls `ui.render` with a component tree (optionally a `replaceViewId` and a presentation hint); the tool validates the tree against the active UI Vocabulary Schema (rejecting unknown node types, invalid tokens, and over-cap trees with typed errors), records the rendered tree in the mission trace (schema version + content hash), and emits a streaming `UiEvent` for the host UI to render. User interactions on rendered trees become `SemanticAction`s that route back to the agent as tool results / steering messages. `confirm`-tier actions are intercepted by a `PolicyGate` that requires explicit approval before delivery. Per-mission-type vocabulary narrowing restricts the tool's input schema to a declared subset, and rendered views coexist with the host's static chrome via an explicit `RenderSlot` contract. The whole surface is pure-Dart (no Flutter imports) and lives under `lib/src/agent/ui_render/`.

## Technical Context

**Language/Version**: Dart 3.13+ (SDK 3.11+ compatible) — pure-Dart package (`sdk: ^3.11.0`).

**Primary Dependencies**: `zuraffa core` (this package), `mcp` runtime tool contracts (`lib/src/core/module/mcp_tool.dart`), `crypto 3.0.7` (already in transitive resolution graph via `uuid`/`minio`/`opentelemetry`).

**Storage**: N/A — render trees are kept in-memory on the active `UiRenderTool` instance and recorded into the in-memory `MissionTraceRecorder`. Persistence to disk/DB is out of scope (per Assumptions, mission traces persist via the existing mission store).

**Testing**: `dart test` (package:test ^1.25.0). Tests live under `test/agent/ui_render/...` mirroring source layout. No `flutter_test` — pure Dart.

**Target Platform**: In-process agent runtime; host UI renders whatever it wants (Flutter, TUI, web) by consuming `UiEvent`s. The pure-Dart package only emits logical events.

**Project Type**: library (subsystem under `zuraffa` core).

**Performance Goals**: render <2s (SC-001); interaction→follow-up update <5s e2e (SC-002). Tracked structurally; not benchmarked in this delivery.

**Constraints**:
- Pure Dart — NO `package:flutter` import anywhere in `lib/src/agent/ui_render/**` or its tests.
- No new dependencies added to `pubspec.yaml` (reuse transitive `crypto` already present).
- Existing pubspec `dependency_overrides:` block must remain removed.
- Each FR maps to one or two focused tests; no over-engineering.

**Scale/Scope**: in-process agent UI loop — single mission at a time, multiple views per mission.

## Constitution Check

Pass — no constitution violations identified. Pure-Dart implementation; no Flutter dependency introduced. The `.specify/memory/constitution.md` is in template form (placeholders); the project's `AGENTS.md` constraints (canonical v5 workflow, no `flutter_test` in pure-Dart paths) are respected — no generated code is produced by this feature, only runtime tool/event primitives.

## Project Structure

### Documentation (this feature)

```text
specs/023-agent-plugin-ui-render/
├── spec.md                       # Authoritative input (FR-001..008, SC-001..004)
├── plan.md                       # This file
├── tasks.md                      # Dependency-ordered task list
├── checklists/requirements.md    # Spec quality checklist (existing draft)
└── tdd/
    ├── test-list.md              # Behavior→test mapping table
    ├── red-evidence.md           # RED snapshot of failing tests before implementation
    └── verification.md           # Final TDD discipline + AC coverage audit
```

### Source Code (repository root)

```text
zuraffa/                                    # pure-Dart core package
├── pubspec.yaml                            # unchanged (no new deps)
└── lib/
    ├── zuraffa.dart                        # + export src/agent/ui_render/ui_render.dart
    └── src/agent/ui_render/
        ├── ui_render.dart                   # barrel re-export of public surface
        ├── ui_vocabulary_schema.dart        # UiVocabularySchema + ValidationResult + typed errors
        ├── rendered_view.dart               # RenderedView (view id + tree + schemaVersion + contentHash)
        ├── semantic_action.dart             # SemanticAction (action id + args + tier)
        ├── ui_render_event.dart             # sealed UiRenderEvent (render/replace/interaction/policy/done)
        ├── ui_event_channel.dart             # UiEventChannel — StreamController of UiRenderEvent
        ├── ui_render_tool.dart               # UiRenderTool (tree → view id; emits; records trace)
        ├── policy_gate.dart                 # PolicyGate — intercepts confirm-tier actions
        ├── mission_trace_recorder.dart      # MissionTraceRecorder — schema version + content hash
        └── vocabulary_narrowing.dart        # per-mission-type subset filter
```

### Tests

```text
test/agent/ui_render/
├── ui_vocabulary_schema_test.dart
├── rendered_view_test.dart
├── semantic_action_test.dart
├── ui_render_tool_test.dart
├── ui_event_channel_test.dart
├── policy_gate_test.dart
├── mission_trace_recorder_test.dart
└── vocabulary_narrowing_test.dart
```

**Structure Decision**: Single pure-Dart package, no nested sub-packages. The `lib/src/agent/` namespace is new (no prior agent code) — established here for future agent-side work (policy shell, mission kernel, runtime plugin, etc.).

## Phases

### Phase 0 — Setup (done)

Created `lib/src/agent/ui_render/` directory and barrel file; exported from `lib/zuraffa.dart`. No new dependencies added to `pubspec.yaml`.

### Phase 1 — Foundational data types (done)

`UiVocabularySchema` (allowed node types, allowed style tokens, node cap) with `validate(tree)` returning a `ValidationResult`. `RenderedView` (view id, tree, schema version, content hash). `SemanticAction` (action id, args, tier). `UiRenderEvent` sealed type.

### Phase 2 — Render tool + event channel (done)

`UiRenderTool.render(tree, {replaceViewId, hint})` validates against the active schema, throws typed errors on failure, records the render in `MissionTraceRecorder`, and emits a streaming `UiRenderEvent` to `UiEventChannel`. Progressive partial-tree streaming supported via `renderStream`.

### Phase 3 — Action routing + policy gate (done)

`PolicyGate.intercept(action)` blocks `confirm`-tier actions until `approve`/`deny` is called; emits `actionBlocked` events when denied and forwards approved actions to the agent via the configured `ActionRouter`.

### Phase 4 — Vocabulary narrowing + mission trace (done)

`vocabularyNarrowing(missionType, baseSchema)` returns a `UiVocabularySchema` subset; the `UiRenderTool` consults the narrowed schema for mission-aware validation. `MissionTraceRecorder` stores rendered trees with `schemaVersion` + `contentHash` for replay/audit.

### Phase 5 — Tests + verification (done)

Tests for every FR + edge cases. `dart analyze` clean; `dart test` green on the new test files. TDD artifacts (test-list, red-evidence, verification) authored.

## Complexity Tracking

No constitution violations — table intentionally empty.
