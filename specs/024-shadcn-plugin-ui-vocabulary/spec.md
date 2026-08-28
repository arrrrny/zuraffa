# Feature Specification: shadcn Plugin — UI Vocabulary Authority

**Feature Branch**: `024-shadcn-plugin-ui-vocabulary`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "shadcn plugin: UI vocabulary authority — schema export, composite codegen (zfa make --ui), zfa ui validate/preview. This feature originates from GitHub issue #391 (https://github.com/arrrrny/zuraffa/issues/391). Make the shadcn plugin the UI vocabulary authority: export schema, composite codegen via `zfa make --ui`, and `zfa ui validate/preview` commands."

**Source Issue**: https://github.com/arrrrny/zuraffa/issues/391

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Schema Export (Priority: P1)

As a **plugin developer / AI agent orchestrator**, I want the shadcn plugin to export the full UI component vocabulary as a versioned JSON Schema so that agents and tools can discover which components, props, tokens, and structural constraints are available without inspecting source code.

**Why this priority**: The schema export is the foundation — without it, no downstream consumer (agent plugin, CI validator, prompt author) can reliably work with the UI vocabulary. Every other capability in this feature depends on a machine-readable schema existing.

**Independent Test**: Can be fully tested by running `zfa ui schema` and validating the output against known built-in components. The output must be stable (diff-stable) across consecutive runs and must cover the fork's full built-in vocabulary.

**Acceptance Scenarios**:

1. **Given** a project with the shadcn plugin installed and the flutter-shadcn-ui fork providing built-in nodes, **When** the user runs `zfa ui schema`, **Then** a JSON Schema file is emitted containing per-component definitions (props, enums, children constraints), structural nesting rules, token enums, action-ID grammar, and tree depth/count caps.
2. **Given** a freshly exported schema, **When** the user runs `zfa ui schema` a second time with no changes, **Then** the output is byte-identical to the first run (diff-stable).
3. **Given** the exported schema, **When** a consumer parses it, **Then** the schema carries a `schemaVersion` field and every component definition is self-contained and independently valid JSON Schema.
4. **Given** the schema is consumed by the agent plugin's `ui.render` tool, **When** the agent plugin reads the schema, **Then** the tool's `inputSchema` can be derived directly from the exported artifact without manual mapping.

---

### User Story 2 — Composite Component Codegen (Priority: P1)

As a **project developer**, I want to run `zfa make <ComponentName> --ui` to scaffold a project-specific composite component (e.g., `ProductOfferCard`) as a first-class vocabulary entry — including its node entity, renderer extension, and schema registration — so that the agent can choose and render it just like any built-in component.

**Why this priority**: Composite codegen makes project-specific UI reusable by agents. Without it, every project-specific card must be hand-coded and manually registered, defeating the purpose of a vocabulary authority.

**Independent Test**: Can be tested by running `zfa make OfferCard --ui` and verifying that: (a) a node entity file is generated, (b) a renderer extension is generated, (c) the component appears in the next `zfa ui schema` export, and (d) a sample payload using `OfferCard` validates against the schema.

**Acceptance Scenarios**:

1. **Given** a project with the shadcn plugin installed, **When** the user runs `zfa make OfferCard --ui`, **Then** the system generates a node entity, a renderer extension, and a schema registration entry for `OfferCard`.
2. **Given** `OfferCard` has been generated via `zfa make --ui`, **When** the user runs `zfa ui schema`, **Then** `OfferCard` appears in the exported vocabulary alongside built-in components with correct props and children constraints.
3. **Given** a JSON payload that references `OfferCard`, **When** the user runs `zfa ui validate` on that payload, **Then** the validation passes (assuming the payload is structurally correct).
4. **Given** `OfferCard` has been generated, **When** the user renders a payload containing `OfferCard` in a preview harness, **Then** the component renders visually without runtime errors.

---

### User Story 3 — Validation (Priority: P2)

As a **prompt engineer / agent developer**, I want `zfa ui validate <file>` to check a UI payload against the schema and structural rules, returning precise diagnostics for any violations, so that I can fix payloads before deploying them to agents or committing them to the repository.

**Why this priority**: Validation catches errors early — in CI, in agent loops, and during prompt authoring. It prevents broken payloads from reaching runtime.

**Independent Test**: Can be tested by feeding intentionally malformed payloads to `zfa ui validate` and verifying that each error category (unknown node, bad token, raw color, depth cap, count cap, invalid action) is caught with an actionable diagnostic message.

**Acceptance Scenarios**:

1. **Given** a valid UI payload, **When** the user runs `zfa ui validate payload.json`, **Then** the command exits with code 0 and reports no errors.
2. **Given** a payload referencing an unknown node type, **When** the user runs `zfa ui validate`, **Then** the diagnostic identifies the unknown node by name and position in the tree.
3. **Given** a payload that violates a structural constraint (depth cap, child count cap, invalid nesting), **When** the user runs `zfa ui validate`, **Then** the diagnostic pinpoints the exact node and the specific constraint violated.
4. **Given** a payload containing a raw color value instead of a token reference, **When** the user runs `zfa ui validate`, **Then** the diagnostic identifies the raw color and suggests the correct token format.
5. **Given** a payload with an invalid action ID, **When** the user runs `zfa ui validate`, **Then** the diagnostic identifies the malformed action and states the valid action-ID grammar.

---

### User Story 4 — Preview (Priority: P2)

As a **prompt engineer / agent developer**, I want `zfa ui preview <file>` to render a UI payload in a harness window so that I can visually inspect the output during my development loop without deploying to a device.

**Why this priority**: Preview accelerates the prompt-authoring feedback loop. Without it, authors must deploy to a device or emulator to see results, which is slow and disrupts flow.

**Independent Test**: Can be tested by running `zfa ui preview` on a known-good fixture payload on macOS and verifying that a window appears with the rendered components.

**Acceptance Scenarios**:

1. **Given** a valid UI payload file, **When** the user runs `zfa ui preview payload.json`, **Then** a harness window opens and renders the component tree.
2. **Given** a payload referencing a composite component generated via `zfa make --ui`, **When** the user runs `zfa ui preview`, **Then** the composite renders correctly in the harness window.
3. **Given** a payload that fails validation, **When** the user runs `zfa ui preview`, **Then** the command reports the validation errors and does not attempt to render.

---

### User Story 5 — Versioning & Stability (Priority: P2)

As a **platform maintainer**, I want the vocabulary schema to carry a `schemaVersion` and for exports to be stable and diffable, so that breaking changes are signaled clearly, apps can pin the vocabulary version their renderer supports, and agents receive the matching schema for their runtime.

**Why this priority**: Versioning prevents silent breakage between schema consumers (agents, CI, renderers) and the plugin. Without it, a plugin update can silently invalidate all downstream consumers.

**Independent Test**: Can be tested by bumping `schemaVersion`, re-exporting, and verifying that the old schema and new schema are not byte-identical, and that a consumer pinned to the old version correctly rejects the new schema.

**Acceptance Scenarios**:

1. **Given** an exported vocabulary schema, **When** the user inspects the output, **Then** it contains a `schemaVersion` field with a semver-compatible value.
2. **Given** a breaking change to the vocabulary (removed component, changed props), **When** the schema is re-exported, **Then** the `schemaVersion` has been bumped and the export is diffable against the previous version.
3. **Given** an app pinned to vocabulary version X, **When** a schema export produces version Y (Y > X), **Then** the pin mismatch is detectable and the app can surface a clear upgrade signal.

---

### Edge Cases

- What happens when `zfa ui schema` is run but the shadcn plugin is not installed? The command must fail with a clear diagnostic ("shadcn plugin not found — install it first").
- What happens when `zfa make <Name> --ui` is given a name that collides with an existing built-in component? The command must reject the name with a list of available reserved names.
- What happens when `zfa ui validate` receives a file that is not valid JSON? The command must report a parse error with file path and line/column.
- What happens when `zfa ui preview` is run on a non-macOS platform? The command must fail with a platform-not-supported message (or gracefully degrade).
- What happens when the node registry is empty (no built-ins, no composites)? `zfa ui schema` must still produce a valid (minimal) schema with `schemaVersion` and an empty components list.
- What happens when a composite component's renderer extension conflicts with an existing renderer? The codegen must detect and reject the conflict at scaffold time.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST export the full UI component vocabulary as a versioned JSON Schema via `zfa ui schema`, covering per-component props, enums, children constraints, structural nesting rules, token enums, action-ID grammar, and tree caps.
- **FR-002**: System MUST scaffold project-specific composite components via `zfa make <Name> --ui`, generating a node entity, renderer extension, and schema registration entry that become first-class vocabulary entries.
- **FR-003**: System MUST validate UI payloads against the schema and structural rules via `zfa ui validate <file>`, returning actionable diagnostics for each violation category (unknown node, bad token, raw color, depth/count cap, invalid action).
- **FR-004**: System MUST render a UI payload in a preview harness window via `zfa ui preview <file>` on macOS, for visual inspection during prompt-authoring workflows.
- **FR-005**: System MUST carry a `schemaVersion` in the exported schema, support stable/diffable exports, and detect version pin mismatches between apps and schema versions.
- **FR-006**: System MUST register the vocabulary export as a discoverable capability within zuraffa's ShadcnPlugin capability system, making it accessible via MCP.
- **FR-007**: System MUST reserve built-in component names and reject composite scaffolding that collides with them.
- **FR-008**: System MUST validate that all commands (`zfa ui schema`, `zfa ui validate`, `zfa ui preview`) fail with clear, actionable error messages when preconditions are not met (plugin missing, file not found, invalid JSON, unsupported platform).

### Key Entities

- **UI Vocabulary Schema**: The versioned JSON artifact exported by `zfa ui schema`. Contains component definitions, structural rules, token enums, action-ID grammar, and tree caps. Consumed by agent tools, CI pipelines, and prompt authors.
- **Composite Component**: A project-specific UI node (e.g., `ProductOfferCard`) scaffolded via `zfa make --ui`. Consists of a node entity, renderer extension, and schema registration. Becomes a first-class vocabulary entry.
- **Schema Version**: A semver-compatible identifier carried by the vocabulary schema. Bumped on breaking changes. Used by apps and agents to pin and verify compatibility.
- **Node Registry**: The combined set of built-in nodes (from the flutter-shadcn-ui fork) and project composites. Walked by `zfa ui schema` to produce the vocabulary.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `zfa ui schema` output validates the fork's full built-in vocabulary and is diff-stable across consecutive runs with no code changes.
- **SC-002**: `zfa make <Name> --ui` generates a composite that is usable in a payload, validatable via `zfa ui validate`, and renderable end-to-end via `zfa ui preview`.
- **SC-003**: `zfa ui validate` catches all five error categories (unknown node, bad token, raw color, depth/count cap, invalid action) with precise, actionable diagnostics — zero false negatives on a curated test corpus.
- **SC-004**: The exported schema is consumed as-is by the agent plugin's `ui.render` tool definition with no manual transformation (integration test passes).

## Assumptions

- The flutter-shadcn-ui fork (arrrrny/flutter-shadcn-ui) already provides the UINode system — node model, renderer, and validator library — as the foundation for this feature.
- The Zuraffa agent plugin (arrrrny/zuraffa_agent) will consume the exported schema directly as the `ui.render` tool's `inputSchema` (issue #392).
- The shadcn plugin's capability registration system already supports MCP-discoverable capabilities; this feature adds vocabulary export as a new capability.
- Preview rendering targets macOS first; other platforms are out of scope for v1.
- The `zfa` CLI already supports the `--ui` flag namespace or can be extended to support it without breaking existing commands.
- Schema versioning follows semver; major version bumps signal breaking changes to consumers.
