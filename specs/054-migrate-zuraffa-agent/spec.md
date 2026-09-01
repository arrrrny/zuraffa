# Feature Specification: Migrate zuraffa_agent to Zuraffa v6

**Feature Branch**: `054-migrate-zuraffa-agent`

**Created**: 2026-09-01

**Status**: Draft

**Input**: GitHub issue #676 (https://github.com/arrrrny/zuraffa/issues/676)

## Overview

Migrate the `zuraffa_agent` package — the agent engine of the Zuraffa ecosystem — to be fully rebuilt on Zuraffa v6. This is a sub-issue of the EPIC #214 migration plan. The package currently exposes loop execution, session trees, tool dispatch, MCP client, provider configuration, sub-agent orchestration, and evaluation harness capabilities. The migration rewrites the entire codebase on Zuraffa v6 so the package's architecture is consistent with the broader Zuraffa framework, uses its entity system, repository pattern, DI conventions, and code-generation tooling throughout, and publishes a semver-major version bump to pub.dev.

## User Scenarios & Testing

### User Story 1 - Migrate Core Agent Engine to Zuraffa v6 (Priority: P1)

As a Zuraffa ecosystem developer, I want `zuraffa_agent` rewritten on Zuraffa v6 so that all agent capabilities (loop execution, session management, tool dispatch, MCP client, provider orchestration, sub-agent dispatch, and evaluation harness) are built on the same architectural foundation as the rest of the framework.

**Why this priority**: `zuraffa_agent` is a foundational, widely-depended-on package. Migrating it first unlocks all downstream migrations in EPIC #214 and ensures a consistent developer experience across the ecosystem.

**Independent Test**: Can be validated by running the package's full test suite against the migrated codebase and confirming that existing consumers can upgrade without breaking changes.

**Acceptance Scenarios**:

1. **Given** the migrated `zuraffa_agent` codebase, **When** a developer runs `dart test`, **Then** all tests pass with the same coverage as the pre-migration codebase.
2. **Given** the migrated package is published to pub.dev, **When** an existing consumer upgrades their dependency, **Then** the upgrade is non-breaking or provides a documented migration path in the CHANGELOG.
3. **Given** the migrated agent engine, **When** an agent loop runs a multi-turn session, **Then** the session state, turn records, tool invocations, and usage ledger are persisted consistently.
4. **Given** the migrated MCP client layer, **When** a session uses MCP tools, **Then** tool calls are dispatched, results are returned, and invocation records are persisted.

---

### User Story 2 - Adopt Full Zuraffa Architecture Across All Layers (Priority: P1)

As a Zuraffa package maintainer, I want the migrated `zuraffa_agent` to use Zuraffa v6's canonical patterns — Zorphy entities, repository abstractions, datasource adapters, DI service locator, and `zfa make` generation — so that the package is structurally indistinguishable from other Zuraffa-first packages.

**Why this priority**: Consistent architecture reduces the maintenance burden, enables uniform tooling, and makes it easier for contributors familiar with Zuraffa to work across any package in the ecosystem.

**Independent Test**: Can be validated by auditing the migrated package against the Zuraffa v6 architecture checklist and confirming all layers follow the canonical pattern.

**Acceptance Scenarios**:

1. **Given** the migrated codebase, **When** the entity layer is inspected, **Then** every entity is a Zorphy class with generated adapters and no hand-written serialization logic.
2. **Given** the migrated data layer, **When** the datasources and repositories are inspected, **Then** they follow the Zuraffa datasource/repository contract and use the DI service locator for instantiation.
3. **Given** the migrated engine layer, **When** the loop executor and event bus are inspected, **Then** they are injectable via the DI system and use Zuraffa domain services for cross-cutting concerns.
4. **Given** the migrated codebase, **When** `dart analyze` is run, **Then** there are no violations of the Zuraffa lint rules.

---

### User Story 3 - Publish Migrated Package to pub.dev (Priority: P1)

As a Zuraffa publisher, I want the migrated `zuraffa_agent` published to pub.dev under the `zuzu.dev` publisher with a semver-major version bump so that consumers can adopt the new Zuraffa-v6-native version.

**Why this priority**: Publishing is the delivery mechanism for all migration value. Without a published version, no consumer can upgrade.

**Independent Test**: Can be validated by running `dart pub publish --dry-run` successfully and confirming the package resolves without conflicts in a fresh `dart pub get`.

**Acceptance Scenarios**:

1. **Given** the migrated codebase, **When** `dart pub publish --dry-run` is executed, **Then** the publisher metadata is correct (package name, publisher, version, description) and the publish would succeed.
2. **Given** the migrated package is published, **When** a new consumer adds it as a dependency, **Then** `dart pub get` resolves without version conflicts.
3. **Given** the migrated package is published, **When** the CHANGELOG is read, **Then** it documents every breaking change from the previous version with a migration guide.

---

### User Story 4 - Preserve Evaluation and Replay Capabilities (Priority: P2)

As an agent framework evaluator, I want the migrated `zuraffa_agent` to retain all evaluation and replay capabilities (cassette replay, pass@k metrics, golden mission, suite gates) so that existing eval workflows continue to work without modification.

**Why this priority**: Evaluation tooling is critical for agent quality assurance. Breaking it would block all teams that rely on it for regression testing.

**Independent Test**: Can be validated by running the eval test suite against the migrated codebase and confirming all pass@k metrics, cassette replay sessions, and suite gate results match pre-migration baselines.

**Acceptance Scenarios**:

1. **Given** the migrated codebase, **When** the eval test suite runs, **Then** all `pass_at_k` and `pass_k_empirical` calculations produce the same results as the pre-migration codebase.
2. **Given** the migrated codebase, **When** a cassette replay session is executed, **Then** the LLM client replays recorded responses and the tool invocation sequence matches the original session.
3. **Given** the migrated codebase, **When** a golden mission suite gate is evaluated, **Then** the pass/fail determination matches the pre-migration baseline.

---

### Edge Cases

- What happens when a Zuraffa v6 migration introduces a breaking change to an entity schema that is already in use by existing `zuraffa_agent` consumers? The migration must bump the major version and provide a documented migration path in the CHANGELOG.
- What happens when the migration reveals that a previously standalone layer (e.g., the LLM transport layer) cannot be expressed using Zuraffa's patterns without losing functionality? The gap must be reported to the Zuraffa core team and resolved before the package is published.
- What happens when the migrated package's test suite reveals a regression in behavior (e.g., session persistence, tool dispatch ordering, event bus delivery) compared to the pre-migration baseline? The regression must be fixed before publishing.
- What happens when a dependency of `zuraffa_agent` is itself part of the EPIC #214 migration and not yet available in a Zuraffa-v6-native form? The migration plan must account for dependency ordering and flag blocking packages.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST rewrite all agent engine components (loop executor, event bus, mission runner, memory distiller, tool dispatcher, sub-agent dispatch) as Zuraffa v6 domain services injected via the DI service locator.
- **FR-002**: The system MUST rewrite all data entities (agent session, turn record, tool invocation record, usage ledger entry, compaction entry, and all sub-agent entities) as Zorphy classes with generated adapters and no hand-written serialization.
- **FR-003**: The system MUST rewrite all datasources (JSONL entity storage, repetition tracker, stop policy, sub-agent instance store, tool call signature, turn record remote, usage ledger entry remote) as Zuraffa datasource adapters with mock counterparts for testing.
- **FR-004**: The system MUST rewrite all repositories (tool invocation record, turn record, usage ledger entry, stop policy, plan state) as Zuraffa repository implementations.
- **FR-005**: The system MUST preserve all existing public APIs of `zuraffa_agent` in the migrated version, or document each breaking change as a semver-major bump with a migration path in the CHANGELOG.
- **FR-006**: The system MUST preserve all existing evaluation and replay capabilities (cassette replay, pass@k, golden mission, suite gate, recorded traffic) with identical behavioral semantics.
- **FR-007**: The system MUST run the full test suite (`dart test`) and achieve the same or higher code coverage as the pre-migration codebase before publishing.
- **FR-008**: The system MUST publish the migrated package to pub.dev under the `zuzu.dev` publisher with a semver-major version bump and an updated CHANGELOG.
- **FR-009**: The system MUST update the package `pubspec.yaml` to use `zuraffa ^6.0.0` (or the appropriate stable v6 range) as the framework dependency.
- **FR-010**: The system MUST use `zfa make` for generating new architecture layers (repositories, datasources, use cases) consistent with the Zuraffa v5 contract.

### Key Entities

- **AgentSession**: Represents an active agent session. Key attributes: session ID, creation timestamp, model configuration, stop policy, current state, compaction strategy. Migrated as a Zorphy entity with local and remote datasources.
- **TurnRecord**: Represents a single turn within a session. Key attributes: turn ID, session reference, input, output, tool invocations, model used, token usage, timestamp. Migrated as a Zorphy entity.
- **ToolInvocationRecord**: Represents a single tool call within a turn. Key attributes: invocation ID, turn reference, tool name, arguments, result, duration, error state. Migrated as a Zorphy entity.
- **UsageLedgerEntry**: Represents a billing/usage record for an API call. Key attributes: entry ID, session reference, model, token counts, cost estimate, timestamp. Migrated as a Zorphy entity.
- **SubAgentInstance**: Represents a sub-agent spawned within a parent session. Key attributes: instance ID, parent session, sub-agent spec, current state, result. Migrated as a Zorphy entity.
- **EngineLoop**: Represents the agent execution loop configuration. Key attributes: loop ID, safety rails, stop policy, oversized result policy, steering queue, session branch. Migrated as a Zuraffa domain service.
- **MCPTransport**: Represents the MCP client transport layer. Key attributes: transport type (stdio, SSE), endpoint, reconnect policy, tool listing cache. Migrated as a Zuraffa domain service.
- **EvalSuite**: Represents a named evaluation suite with pass@k thresholds and golden missions. Key attributes: suite name, missions, pass@k config, results history. Migrated as a Zorphy entity.

## Success Criteria

### Measurable Outcomes

- **SC-001**: 100% of the existing `zuraffa_agent` test suite passes on the migrated codebase.
- **SC-002**: The migrated package publishes successfully to pub.dev under the `zuzu.dev` publisher with a semver-major version bump.
- **SC-003**: All evaluation and replay test cases produce identical results before and after migration (zero behavioral regressions in pass@k, cassette replay, suite gates).
- **SC-004**: The migrated codebase uses Zuraffa v6 canonical patterns (Zorphy entities, datasource/repository contracts, DI service locator) across all layers with zero exceptions.
- **SC-005**: Existing consumers can upgrade to the migrated version with zero compile errors after following the documented migration path (for any breaking changes).

## Assumptions

- Zuraffa v6 is stable and its entity system, datasource/repository contracts, and DI service locator are sufficiently feature-complete to express all existing `zuraffa_agent` patterns without workarounds.
- The existing test suite provides sufficient coverage to detect behavioral regressions during migration; no new tests are needed beyond porting the existing ones.
- The package's current public API surface is well-documented through its pub.dev page and source, allowing identification of breaking changes.
- The migration team will use `zfa make` and `zfa build` as the primary code generation tools per the v5 generation contract.
- No new features are in scope — this is a migration/rewrite only; any desired enhancements are tracked as separate issues.
- The pub.dev publishing credentials for the `zuzu.dev` publisher are available and the package metadata (name, description, license) is correct.
