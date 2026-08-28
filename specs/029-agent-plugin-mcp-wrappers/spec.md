# Feature Specification: AgentPlugin — McpTool Wrappers for UseCases

**Feature Branch**: `029-agent-plugin-mcp-wrappers`

**Created**: 2026-08-28

**Status**: Draft

**Origin**: GitHub issue [#385](https://github.com/arrrrny/zuraffa/issues/385) — "agent: AgentPlugin — generate McpTool wrappers for every UseCase (--agent flag)"

**Input**: User description: "Extend AgentPlugin to auto-generate McpTool wrappers for every UseCase via a `--agent` flag."

## User Scenarios & Testing *(mandatory)*

<!--
  User stories are PRIORITIZED (P1 = most critical). Each is independently
  testable. The "users" here are Zuraffa app developers who want their
  generated UseCases to appear as callable MCP tools for the ZikZak AI agent
  runtime.
-->

### User Story 1 - Generate MCP tool wrappers for an entity's UseCases (Priority: P1)

A Zuraffa developer runs `zfa make` with the `--agent` flag on an entity that
already has generated UseCases. The generator inspects those UseCases and
produces one MCP tool wrapper file per UseCase under a well-known agent tools
directory. The wrappers are callable through the MCP runtime with zero
hand-written glue code.

**Why this priority**: This is the core value — making every UseCase
automatically available as an MCP tool. Without it, developers must write tool
wrappers by hand, which defeats the automation promise of the agent plugin.

**Independent Test**: A developer runs `zfa make Demo --preset=crud --agent`,
then confirms via `zfa mcp list-tools` (or equivalent runtime inspection) that
every generated UseCase has a corresponding callable tool with correct name,
input schema, and output schema.

**Acceptance Scenarios**:

1. **Given** a Zuraffa entity with generated UseCases (e.g. `ComposeListing`,
   `GetListing`, `DeleteListing`), **When** the developer runs `zfa make Demo
   --preset=crud --agent`, **Then** one tool wrapper file is generated per
   UseCase under `lib/src/agent/tools/`, each implementing the MCP tool
   interface with a namespaced tool name (e.g. `zikzak.listing.compose`).
2. **Given** a generated tool wrapper, **When** the developer inspects the
   `inputSchema`, **Then** it reflects the UseCase's `Params` type fields with
   correct JSON Schema types, required flags, and default values derived from
   entity field metadata.
3. **Given** a generated tool wrapper, **When** the developer inspects the
   `outputSchema`, **Then** it reflects the UseCase's return type with
   appropriate schema mapping (primitives, collections, nested entities,
   nullable fields).

---

### User Story 2 - Idempotent regeneration with safe manual-edit merge (Priority: P1)

A developer regenerates agent tool wrappers after making changes to UseCases.
Running `zfa make --agent` again overwrites only the `// GENERATED` sections;
any manual extensions placed outside those markers survive intact.

**Why this priority**: Regeneration is a core zuraffa generation contract
pillar. Non-idempotent or destructive regeneration breaks the developer workflow
and trust in the tool.

**Independent Test**: Generate tool wrappers, make manual edits in extension
points outside generated markers, regenerate, and confirm: (a) generated
sections reflect the new UseCase state, (b) manual edits are preserved.

**Acceptance Scenarios**:

1. **Given** previously generated tool wrappers with manual extensions outside
   `// GENERATED` markers, **When** the developer regenerates with `--agent`,
   **Then** the generated sections are updated and the manual extensions remain
   untouched.
2. **Given** a UseCase was added to an entity, **When** the developer
   regenerates, **Then** a new tool wrapper file is created for the new UseCase
   while existing tool wrappers are updated if their UseCases changed.
3. **Given** a UseCase was removed from an entity, **When** the developer
   regenerates, **Then** the corresponding tool wrapper file is removed and the
   tool manifest is updated accordingly.

---

### User Story 3 - Auto-generated tool manifest with risk tier metadata (Priority: P2)

A developer or platform operator can view a consolidated tool manifest that
lists every generated tool, its domain grouping, and a risk tier. Tools
originating from UseCases annotated with an internal-only marker receive an
`admin` risk tier by default; all others default to `safe`.

**Why this priority**: The manifest is the discovery and governance surface for
the agent runtime — it lets the platform know what tools exist and which ones
require elevated permissions. It builds on the generation story but is not
required for basic tool generation.

**Independent Test**: After generation, inspect the manifest barrel file and
confirm it lists all generated tools, groups them by domain, and assigns the
correct risk tier based on UseCase annotations.

**Acceptance Scenarios**:

1. **Given** generated tool wrappers for an entity, **When** the developer
   inspects the manifest file, **Then** every tool is listed with its name,
   owning entity, and default risk tier (`safe`).
2. **Given** a UseCase annotated with an internal-only marker, **When** the
   manifest is generated, **Then** the corresponding tool is listed with
   risk tier `admin`.
3. **Given** tools from multiple entities, **When** the manifest is generated,
   **Then** tools are grouped by domain (entity) for easy discovery.

---

### User Story 4 - Opt-in via `--agent` flag or project config (Priority: P2)

A developer opts into agent tool generation either by passing `--agent` on the
command line or by setting `agent: true` in the project configuration file.
When neither is set, no tool wrappers are generated.

**Why this priority**: Opt-in keeps the feature non-intrusive — existing
workflows that don't use the agent plugin are unaffected. This is the
configuration surface that enables the generation stories.

**Independent Test**: Run `zfa make` without `--agent` and confirm no tool
files are generated. Set `agent: true` in config and confirm tools are generated
without the flag.

**Acceptance Scenarios**:

1. **Given** a Zuraffa project, **When** the developer runs `zfa make Demo
   --preset=crud` without `--agent` and without `agent: true` in config,
   **Then** no tool wrapper files or manifest are generated.
2. **Given** a Zuraffa project with `agent: true` in its config, **When** the
   developer runs `zfa make Demo --preset=crud`, **Then** tool wrappers and
   manifest are generated as if `--agent` were passed.
3. **Given** both `--agent` flag and config setting, **When** they conflict
   (flag absent but config true, or flag present but config false), **Then**
   the explicit `--agent` flag takes precedence.

---

### User Story 5 - Schema derivation for complex types (Priority: P3)

The generator correctly maps Zuraffa domain types to JSON Schema for tool
input/output: primitives, enums, nested Zorphy entities, lists, nullable
fields, and DateTime (mapped to ISO-8601 string). Unknown types produce an
open-object schema with documentation.

**Why this priority**: Correct schema derivation is essential for the agent
runtime to validate tool calls and for downstream agents to understand tool
contracts. It refines the generation story with comprehensive type coverage.

**Independent Test**: A schema derivation matrix test covers every supported
type and asserts the generated JSON Schema matches expected shapes.

**Acceptance Scenarios**:

1. **Given** a UseCase with a `String` param, **When** the tool wrapper is
   generated, **Then** the `inputSchema` declares the field as `"type":
   "string"`.
2. **Given** a UseCase with a `DateTime` param, **When** the tool wrapper is
   generated, **Then** the `inputSchema` declares the field as `"type": "string",
   "format": "date-time"`.
3. **Given** a UseCase with a nested Zorphy entity param, **When** the tool
   wrapper is generated, **Then** the `inputSchema` inlines the entity's field
   schema as a nested object.
4. **Given** a UseCase returning `SignalResult<T>`, **When** the tool wrapper
   is generated, **Then** the `outputSchema` unwraps to the schema of `T`.

---

### Edge Cases

- **Entity with no UseCases**: Running `--agent` on an entity that has no
  generated UseCases MUST produce no tool files and no manifest entry, with a
  clear informational message (not an error).
- **UseCase with unresolvable return type**: If the return type cannot be
  mapped to a JSON Schema (e.g. a generic with unresolved type parameter), the
  generator MUST emit the tool with an open-object output schema and log a
  warning, not fail the entire generation.
- **Duplicate tool names across entities**: If two UseCases from different
  entities produce the same namespaced tool name, the generator MUST fail with
  a clear error naming the conflict, not silently overwrite.
- **Mixed flag and config**: When `--agent` is passed but the project has
  `agent: false`, the explicit flag MUST win. When `--no-agent` is passed but
  config is `agent: true`, the explicit flag MUST win.
- **Regeneration with UseCase signature changes**: If a UseCase's params or
  return type change between generations, the tool wrapper MUST be fully
  regenerated to reflect the new contract; stale schemas MUST NOT persist.
- **Existing manually-written tool files**: If a developer has manually written
  a tool file in the agent tools directory that conflicts with a generated name,
  the generator MUST fail with a clear error rather than silently overwriting
  manual work outside of `// GENERATED` markers.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The plugin MUST provide an `AgentPlugin` that implements the
  standard Zuraffa file generator and CLI-aware plugin interfaces, registered in
  the plugin loader with id `agent`.
- **FR-002**: The plugin MUST support an `--agent` flag on `zfa make` that
  triggers tool wrapper generation for the target entity's UseCases.
- **FR-003**: The plugin MUST support a project-level configuration key (`agent:
  true|false`) as an alternative to the `--agent` flag, with the explicit flag
  taking precedence over the config.
- **FR-004**: The plugin MUST introspect generated UseCases by scanning the
  domain use-case directory for the target entity, extracting each UseCase's
  name, parameters (from the Params type), and return type.
- **FR-005**: The plugin MUST generate one tool wrapper file per UseCase under
  `lib/src/agent/tools/{usecase_snake}_tool.dart`, implementing the MCP tool
  interface with a namespaced tool name, input schema, output schema, and a
  call method that resolves the UseCase from dependency injection and maps the
  result.
- **FR-006**: The plugin MUST derive `inputSchema` from the UseCase's Params
  type fields and `outputSchema` from the UseCase's return type, supporting
  primitives, enums, nested entities, lists, nullable fields, DateTime, and
  producing an open-object schema for unresolvable types.
- **FR-007**: The plugin MUST produce a tool manifest barrel file listing all
  generated tools with domain grouping and risk tier metadata (default `safe`;
  `admin` for UseCases annotated with the internal-only marker).
- **FR-008**: The plugin MUST be idempotent — regenerating after changes
  updates only `// GENERATED` sections; manual extensions outside markers
  survive; removed UseCases cause their tool files to be deleted.
- **FR-009**: The plugin MUST fail with a clear, actionable error when tool
  names conflict across entities, when UseCases have unresolvable signatures
  that cannot produce a valid schema, or when manually-written tool files in
  the target directory would be silently overwritten.
- **FR-010**: The plugin MUST generate code that passes `dart analyze` with zero
  warnings in a fresh scaffold, and that compiles and is callable through the
  MCP runtime.

### Key Entities *(include if feature involves data)*

- **AgentPlugin**: The Zuraffa plugin responsible for tool wrapper generation.
  Owns the `--agent` flag registration, UseCase introspection, tool file
  emission, and manifest generation.
- **McpTool Wrapper**: A generated Dart class implementing the MCP tool
  interface for a single UseCase, containing the tool name, input/output
  schemas, and a call method that bridges to the UseCase via DI.
- **Tool Manifest**: A generated barrel file that catalogs all tools for an
  entity (or project) with name, owning entity, and risk tier — the discovery
  surface for the agent runtime.
- **Tool Namespace**: A configurable prefix (default `app`) applied to every
  generated tool name to prevent cross-project collisions (e.g.
  `zikzak.listing.compose`).
- **UseCase Introspection Result**: The extracted metadata from a UseCase —
  name, Params type fields (name, type, required, default), and return type —
  that drives schema generation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `zfa make Demo --preset=crud --agent` produces a set of tool
  wrapper files and a manifest that compile without errors and are callable
  through the MCP runtime.
  - **Mechanical verification**: A generation integration test drives the
    `AgentPlugin` against a fixture CRUD entity, asserts (a) one tool file per
    UseCase exists in the expected output path, (b) the manifest barrel file
    lists every tool, (c) `dart analyze` on the generated files passes with
    zero warnings, and (d) a runtime test invokes each tool via the MCP
    interface and receives a valid result.
- **SC-002**: Schema derivation is correct across the full type matrix
  (primitives, enums, nested entities, lists, nullable, DateTime).
  - **Mechanical verification**: A schema derivation unit test exercises every
    type in the matrix, generates the tool wrapper, and asserts the
    `inputSchema` and `outputSchema` match expected JSON Schema output. DateTime
    is documented as ISO-8601 string.
- **SC-003**: Regeneration is idempotent — running the generator twice on the
  same UseCase state produces no diff, and manual extensions outside `//
  GENERATED` markers survive.
  - **Mechanical verification**: An idempotency test generates tool wrappers,
    records file checksums, regenerates, and asserts checksums are identical.
    A separate merge test injects manual code outside markers, regenerates, and
    asserts the manual code survives.
- **SC-004**: The `--agent` flag and project config interact correctly, with
  the explicit flag taking precedence in all combinations.
  - **Mechanical verification**: A config precedence test exercises four
    combinations (flag on/config on, flag on/config off, flag off/config on,
    flag off/config off) and asserts generation occurs exactly when expected.

## Assumptions

- **MCP runtime and McpTool base class exist (issue #384).** The generated tool
  wrappers depend on an MCP runtime and `McpTool` base type. This feature
  requires issue #384 to be landed first; it does not introduce the runtime
  itself.
- **Zorphy entity field metadata is available.** Schema derivation relies on
  Zorphy's entity field annotations (name, type, required, default) being
  accessible at generation time via AST introspection or a metadata API.
- **Dependency injection container is available at runtime.** Tool call methods
  resolve UseCases from DI (`getIt`/`ZuraffaContainer`). The generator emits
  the resolution call; the DI wiring is an existing zuraffa concern, not
  invented here.
- **Tool namespace is configurable.** The default namespace is `app`, but it
  can be overridden in project config. This is specified here as a behavior
  contract; the configuration surface is an implementation detail.
- **Internal-only risk tier annotation is a Zorphy concern.** The `@AgentInternal`
  annotation and its compile-time semantics are defined by Zorphy (separate
  issue). The AgentPlugin reads this annotation and assigns `admin` risk; it
  does not define the annotation itself.
- **v1 scope: single-project generation.** Cross-project tool discovery and
  runtime-level tool permission enforcement are out of scope for this feature.
  The manifest is a static barrel; runtime gating is a separate concern.
