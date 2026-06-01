# Feature Specification: Zuraffa V5 Foundation

**Feature Branch**: `007-zuraffa-v5-foundation`  
**Created**: 2026-05-31  
**Status**: Draft  
**Input**: User description: "Retire `zfa generate`, make `zfa make` canonical, make Zuraffa the only AI-first enterprise-grade Flutter clean architecture framework, persist plans/blueprints in `.zfa`, and add framework-level platform-aware layout support for multi-platform apps like macOS."

## User Scenarios & Testing _(mandatory)_

### User Story 1 - One Canonical Generation API via `zfa make` (Priority: P1)

A developer or AI agent needs to generate architecture code under strict constraints: use only Zuraffa, no manual boilerplate, no ambiguity. The framework exposes one canonical generation command, `zfa make`, with machine-readable planning/output and clear presets. `zfa generate` is removed in v5 so there is no competing workflow.

**Why this priority**: Multiple competing generation paths (`generate`, `feature`, `make`, direct plugin commands) are the primary source of agent hesitation and orchestration drift.

**Independent Test**: Run `zfa make Product --preset=crud --with=data,vpc,state,di,test,mock --format=json` in a temp workspace and verify the command returns a valid plan/result payload, generates the expected files, and never invokes the removed `generate` path.

**Acceptance Scenarios**:

1. **Given** a new project with a valid entity, **When** the developer runs `zfa make Product --preset=crud --with=data,vpc,state,di,test`, **Then** Zuraffa generates the requested layers deterministically and reports the selected plugins in machine-readable output.
2. **Given** an old workflow that previously used `zfa generate`, **When** the developer tries to run `zfa generate ...` in v5, **Then** the command fails fast with a breaking-change message that points to the equivalent `zfa make`/`zfa feature` workflow.
3. **Given** an AI agent using stdin/json workflows, **When** it runs `zfa make Product --from-stdin --format=json`, **Then** it receives a fully machine-readable success/failure result with the normalized plan, plugin list, warnings, and generated files.

---

### User Story 2 - Deterministic Plugin Orchestration with `.zfa.json` Defaults (Priority: P1)

A team configures project defaults in `.zfa.json` and expects every generation path to consistently apply them without hidden plugin activation or cross-plugin leakage. Plugins run only when selected by plan, preset, defaults, or explicit command arguments.

**Why this priority**: Zuraffa already has strong plugin primitives, but the current orchestration is not cohesive enough for strict, agent-only usage.

**Independent Test**: Create a temp project with `.zfa.json` defaults enabling a small set of plugins, run `zfa make` with and without overrides, and verify only the resolved plugin set executes.

**Acceptance Scenarios**:

1. **Given** `.zfa.json` enables `di`, `route`, and `test` by default, **When** a developer runs `zfa make Product --preset=crud`, **Then** the resolved plan includes those default plugins unless explicitly disabled.
2. **Given** a command disables a defaulted plugin via `--without=route` or equivalent negation, **When** generation runs, **Then** the plugin is excluded from the plan and no route files are generated.
3. **Given** a dry-run or programmatic `CodeGenerator` call, **When** generation is resolved, **Then** the same plugin selection rules are applied as the CLI and unrelated plugins do not self-activate.

---

### User Story 3 - Persistent Agent Memory and Blueprints in `.zfa/` (Priority: P1)

A new AI agent joins an existing project and must immediately understand prior architectural decisions, executed generation commands, selected presets, produced files, and allowed manual zones. Zuraffa stores this information in a dedicated `.zfa/` folder.

**Why this priority**: Agent continuity is essential for AI-first workflows. Previous runs must be inspectable and reusable instead of lost in chat history.

**Independent Test**: Run a generation command in a temp workspace, then verify `.zfa/plans`, `.zfa/runs`, and `.zfa/context.json` contain normalized plan and execution artifacts that another process can read without repository-specific heuristics.

**Acceptance Scenarios**:

1. **Given** a successful `zfa make` run, **When** execution finishes, **Then** Zuraffa stores a normalized plan, a run artifact, and generated file metadata under `.zfa/`.
2. **Given** a project with existing `.zfa/blueprints` and `.zfa/decisions`, **When** another agent reads the workspace, **Then** it can identify the preferred generation workflow, architectural intent, and prior commands without scanning documentation first.
3. **Given** a revert operation, **When** the developer runs the revert command, **Then** the relevant prior plan/run artifacts remain traceable and the revert itself is also logged.

---

### User Story 4 - Platform-Aware Layouts and Shells (Priority: P1)

A team ships one app to mobile, tablet, desktop, web, and macOS. Business logic stays shared, but shells and layouts differ by device/platform. Zuraffa provides framework-level platform-aware presentation structure so these differences are clean, generated, and maintainable instead of ad hoc.

**Why this priority**: Real downstream apps need platform-specific UI composition. Breakpoint-only responsiveness is not enough for macOS/desktop shells, multi-pane layouts, or workspace navigation.

**Independent Test**: Generate a feature with platform layouts enabled and verify the output contains shared presenter/controller/state plus layout/shell extension points for mobile/tablet/desktop/macOS fallback resolution.

**Acceptance Scenarios**:

1. **Given** a feature generated with platform layouts enabled, **When** the developer opens the generated presentation layer, **Then** they see shared logic files plus dedicated layout files such as mobile/tablet/desktop/macOS variants.
2. **Given** a macOS app shell requires a sidebar + detail layout, **When** the framework resolves the active platform/device class, **Then** it selects the macOS shell/layout before falling back to generic desktop or tablet layouts.
3. **Given** no platform-specific layout is implemented for a target, **When** the feature runs on that platform, **Then** Zuraffa uses a documented fallback order without duplicating controller/presenter/state logic.

---

### User Story 5 - Cohesive Documentation, Prompts, and Reliability Defaults (Priority: P1)

A developer or AI agent uses the README, CLI guide, website docs, AGENTS guidance, or MCP docs and always sees the same recommended workflow. The default test suite is hermetic and does not fail because of local services like MinIO.

**Why this priority**: AI-first credibility depends on coherent docs and reliable automation. Contradictory docs and flaky default tests make agents second-guess the framework.

**Independent Test**: Run documentation/reference checks to verify no official v5 docs recommend `zfa generate`, and run the default test suite to confirm local-infra-dependent tests are skipped or gated.

**Acceptance Scenarios**:

1. **Given** a new user reads any official Zuraffa docs surface, **When** they follow the quickstart, **Then** they are instructed to use `zfa entity create`, `zfa make`, and `zfa build`—not removed or conflicting commands.
2. **Given** the default CI test suite runs in a clean environment, **When** no local MinIO instance is available, **Then** MinIO-dependent tests are skipped or isolated and the default suite remains hermetic.
3. **Given** an AI agent is instructed to use only Zuraffa, **When** it reads `.zfa` context plus project docs, **Then** it finds a single clear rule: generate architecture via `zfa`, handcraft only UI composition/layout/manual zones.

---

### Edge Cases

- What happens if a developer tries to use a removed v4 command like `zfa generate`? The CLI should fail fast with a migration message and equivalent v5 command guidance.
- What happens if `zfa make` is invoked from a deleted or invalid current working directory in a subprocess? Root resolution must remain robust and not crash on `Directory.current` access.
- What happens if a preset/group alias like `data` or `vpc` is used? The planner should normalize aliases to real plugin sets deterministically.
- What happens if an entity-dependent command is run before the entity exists? The command should fail fast with exact next-step guidance rather than generating partial architecture accidentally.
- What happens if a project has no platform-specific layout for macOS? The framework should use the documented fallback chain, e.g. macOS → desktop → tablet → mobile.
- What happens when a project is revisited by a new AI agent after many generations? `.zfa/` must contain enough context to resume confidently without reading all generated source code first.

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: System MUST remove `zfa generate` from the v5 public CLI surface.
- **FR-002**: System MUST make `zfa make` the canonical generation command for architecture/code generation workflows.
- **FR-003**: System MUST support machine-readable planning and execution for `zfa make`, including JSON input/output and stdin-based workflows.
- **FR-004**: System MUST resolve a normalized generation plan before execution, including presets, aliases, defaults, explicit inclusions, and explicit exclusions.
- **FR-005**: System MUST execute only the plugins selected by the resolved plan; plugins MUST NOT self-activate merely because they are registered.
- **FR-006**: System MUST apply `.zfa.json` defaults consistently across CLI, feature wrappers, and programmatic generation APIs.
- **FR-007**: System MUST store generation plans, execution runs, and project context in a dedicated `.zfa/` directory.
- **FR-008**: System MUST record enough plan/run metadata for a future agent to understand what was generated, by which command, with which normalized plugin set.
- **FR-009**: System MUST provide a documented boundary between generated architecture code and manually crafted UI code.
- **FR-010**: System MUST support framework-level platform-aware presentation composition with shared business logic and divergent layout/shell files.
- **FR-011**: System MUST define and implement a platform/device fallback strategy for layouts and shells.
- **FR-012**: System MUST keep presenter/controller/state shared across layout variants by default.
- **FR-013**: System MUST provide clear fast-fail errors for missing entities or invalid generation preconditions.
- **FR-014**: System MUST make default test execution hermetic; local-service-dependent tests MUST be gated or isolated from the default suite.
- **FR-015**: System MUST align README, website docs, CLI guide, AGENTS guidance, and agent skills to the same v5 workflow.
- **FR-016**: System MUST preserve transactional generation and revertability while migrating plan storage to `.zfa/`.
- **FR-017**: System MUST expose a project/agent contract that states architecture code is generated only via `zfa` commands and UI manual zones are explicitly defined.
- **FR-018**: System MUST treat Zuraffa v5 as a greenfield-first framework and MAY drop support for retrofit/legacy project structures that conflict with the canonical architecture contract.
- **FR-019**: System MUST fix the domain root to `lib/src/domain` and MUST NOT support custom domain root paths or custom domain output roots.
- **FR-020**: System MUST remove freeform domain-path overrides from the public generation workflow and derive bounded-context/domain placement from Zuraffa conventions instead of arbitrary path input.
- **FR-021**: System MUST assume entities are Zorphy entities by default and MUST remove non-Zorphy entity generation modes and related toggles from the canonical v5 workflow.

### Key Entities

- **Generation Plan**: The normalized execution contract containing name, preset, selected plugins, defaults applied, exclusions, warnings, and resolved execution order.
- **Run Artifact**: The persisted record of an executed plan, including generated files, overwritten files, errors, warnings, timestamps, and duration.
- **Blueprint**: A project-level architectural intent document stored under `.zfa/blueprints/`, used by humans and agents to reuse proven patterns.
- **Decision Record**: A persisted architectural rule, such as entity-first generation, route strategy, shell strategy, cache policy, or manual UI zones.
- **Platform Layout Variant**: A presentation-level layout file specialized for a platform or device class such as mobile, tablet, desktop, macOS, or web.
- **Application Shell**: A generated composition root for page chrome/navigation structure specialized by platform or device class.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: An AI agent under the instruction “use only Zuraffa” can complete a feature generation workflow using only `zfa` commands without needing to guess between `generate`, `feature`, `make`, or manual file creation.
- **SC-002**: All official v5 documentation surfaces recommend the same canonical workflow: `zfa entity create` → `zfa make` → `zfa build`.
- **SC-003**: Default CI/test execution passes in a clean environment without requiring a locally running MinIO instance or other external services.
- **SC-004**: Running `zfa make ... --format=json` returns a normalized plan/result payload that includes plugin selection and generated file metadata.
- **SC-005**: Programmatic generation and CLI generation resolve the same plugin set for equivalent inputs.
- **SC-006**: A generated multi-platform feature contains shared logic plus generated platform/device layout extension points with documented fallback behavior.
- **SC-007**: `.zfa/` artifacts are sufficient for a new agent to identify previous generation commands, project defaults, and prior architectural blueprints.
- **SC-008**: The v5 migration eliminates public references to `zfa generate` from README, website docs, CLI guide, AGENTS guidance, and agent skills.

## Assumptions

- Breaking changes are acceptable in v5 if they materially improve coherence and agent reliability.
- The framework is intentionally greenfield-first in v5; optimizing for strict, clean new-project usage takes priority over supporting mixed or legacy layouts.
- The framework should be opinionated: architecture is generated via `zfa`, while UI composition/layout may be manually crafted inside explicitly documented manual zones.
- Entity-first generation is the preferred default for entity-aware architecture flows unless a command is explicitly for a service/custom use case.
- The domain root is fixed to `lib/src/domain`; v5 does not support custom domain roots or arbitrary domain-path overrides.
- All entities are assumed to be Zorphy entities in v5; non-Zorphy entity modes and toggles are out of scope.
- The existing plugin system, transactional generation, and revert infrastructure remain the foundation but will be unified under a stricter planning contract.
- The existing `ResponsiveViewState` demonstrates basic breakpoint responsiveness, but v5 platform-aware layouts must operate at a broader shell/layout architecture level.
- A downstream app such as `Developer/zik_zak` will be used during implementation/validation as a real-world target for mobile vs desktop/macOS shell divergence, once workspace access is available.
