# Feature Specification: Gym Exercise — Agent Rewrite of a Dart Package Using Only zfa

**Feature Branch**: `021-gym-agent-rewrite-exercise`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "Gym gap: no exercise trains an agent to rewrite a Dart package using only zfa. This feature originates from GitHub issue #478 (https://github.com/arrrrny/zuraffa/issues/478). Add a GYM exercise that trains an agent to rewrite an existing Dart package using only the zfa CLI, closing the gap where no such exercise exists."

## Summary

The Zuraffa GYM currently has no exercise that trains an agent to **rewrite an existing Dart package using only `zfa`**. Issue #477 demonstrated this gap: an agent assigned a `zfa`-only rewrite of `zikzak_inappwebview` failed because no exercise or "muscle" exists for that task class. This feature adds that missing exercise to the GYM registry.

The exercise must teach an agent to:
1. Detect whether a target Dart package is a Zuraffa package or a plain Dart/Flutter package.
2. If Zuraffa-compatible: use `zfa` CLI commands to rewrite entities, generate architecture, and verify the result.
3. If not Zuraffa-compatible: cleanly stop and report (file an issue or document the limitation) instead of silently producing broken output.

This closes a training-coverage gap so that agents can be exercised and evaluated on `zfa`-only rewrite tasks, and will either succeed in scope or fail with a clear, actionable report.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Agent rewrites a compatible Dart package using only zfa (Priority: P1)

As an agent operator, I want a GYM exercise that trains an agent to rewrite a compatible Dart package entirely through `zfa` CLI commands so that the agent can be evaluated on this task class and produce correct, `zfa`-generated output.

**Why this priority**: This is the core gap identified in #478. Without it, no agent can be exercised on `zfa`-only rewrites, and every attempt either breaks silently or requires manual intervention.

**Independent Test**: Can be fully tested by running the exercise against a known compatible sample package in a sandbox, verifying the output files are `zfa`-generated (correct structure, compilable), and confirming the exercise grades pass.

**Acceptance Scenarios**:

1. **Given** a compatible Dart package in the exercise sandbox, **When** the agent runs the exercise using only `zfa` CLI commands, **Then** the rewritten package contains `zfa`-generated entities, repositories, and architecture files matching the expected structure.
2. **Given** the exercise completes, **When** the verification command runs, **Then** the output compiles and all assertions pass (exit 0).
3. **Given** a compatible package with entities defined, **When** the agent runs `zfa entity create` and `zfa make` for each entity, **Then** the generated architecture matches the canonical v5 layout (`lib/src/domain/entities/{entity_snake}/{entity_snake}.dart`).

---

### User Story 2 — Agent detects a non-compatible package and stops with a clear report (Priority: P1)

As an agent operator, I want the exercise to teach agents to detect when a target package is not `zfa`-compatible and to stop with a clear, actionable report instead of producing broken output — so that agents do not silently misfire on out-of-scope packages.

**Why this priority**: Issue #477's core failure was not the lack of a rewrite capability, but the agent's inability to stop and report when the task was out of scope. This is equally critical as Story 1.

**Independent Test**: Can be fully tested by running the exercise against a known non-compatible (plain Dart/Flutter) package and verifying the agent produces a structured issue/report rather than attempting and failing a `zfa` rewrite.

**Acceptance Scenarios**:

1. **Given** a non-Zuraffa Dart package in the exercise sandbox, **When** the agent attempts to assess package compatibility, **Then** it detects the package is not Zuraffa-compatible and stops before attempting `zfa` rewrite commands.
2. **Given** a non-compatible package detected, **When** the agent stops, **Then** it produces a structured report (or template issue) that states: the package is not Zuraffa-compatible, why it is not compatible, and what would be required to make it compatible.
3. **Given** a non-compatible package, **When** the exercise grades the output, **Then** the exercise passes (exit 0) because the agent correctly followed the stop-and-report protocol rather than attempting an invalid rewrite.

---

### User Story 3 — Exercise is registered in the GYM and runnable via standard commands (Priority: P2)

As a developer, I want the new exercise to be registered in the GYM registry (`gym.yaml`) and runnable via standard `gym` commands so that it can be discovered and executed by the miki GYM runner and CI pipelines.

**Why this priority**: The exercise must be integrated into the existing GYM infrastructure to be useful; however, the exercise content (Stories 1-2) must be designed before integration.

**Independent Test**: Can be fully tested by running `gym run` (or the equivalent runner command) against the new exercise ID and confirming it executes and grades correctly.

**Acceptance Scenarios**:

1. **Given** the exercise is added to `gym.yaml`, **When** the GYM runner is invoked with the exercise ID, **Then** the exercise executes, produces output in `.gym/.sandbox/`, and grades the result.
2. **Given** the exercise is registered, **When** listed via `gym --help` or equivalent, **Then** the new exercise appears in the available exercises list with its brief description.

---

### User Story 4 — Exercise is scoped to a concrete, completable package (Priority: P2)

As a developer, I want the exercise to specify a concrete sample Dart package as the rewrite target so that the exercise is repeatable and its expected output is deterministic.

**Why this priority**: Without a concrete target, the exercise is too open-ended to grade or reproduce consistently. This scopes the exercise to something completable now while #477 remains open.

**Independent Test**: Can be fully tested by confirming the exercise sandbox includes or references a specific, known package, and that running the exercise against it produces deterministic, comparable output.

**Acceptance Scenarios**:

1. **Given** the exercise definition, **When** a developer reads it, **Then** the target package (name, repository, or embedded fixture) is explicitly identified.
2. **Given** the target package is fixed, **When** the exercise is run multiple times in clean sandboxes, **Then** the output structure and key files are consistent across runs.

---

### Edge Cases

- What happens when the exercise sandbox cannot download or access the sample package? (exercise should fail with a clear setup error, not a misleading grade)
- What happens when `zfa` commands produce output that partially matches expectations but has gaps? (exercise should grade as FAIL and log which assertions failed)
- What happens when the agent attempts to use non-`zfa` tools (e.g., hand-writing Dart files) during the exercise? (exercise should detect and fail the run — the exercise is `zfa`-only)
- What happens when the agent runs `zfa` commands on an empty/blank package (no entities defined yet)? (exercise should guide entity creation before architecture generation, or fail with a clear message)
- What happens when the exercise is run on a system without `zfa` installed? (setup phase should fail fast with an actionable error)
- What happens when the target package requires `zfa` capabilities not yet implemented (per #477)? (exercise should handle gracefully — either skip that part or document it as a known limitation)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a GYM exercise definition that trains an agent to rewrite a Dart package using only `zfa` CLI commands, registered in the project's `gym.yaml` or equivalent GYM registry.
- **FR-002**: Exercise MUST include a compatibility-detection step that determines whether the target package is Zuraffa-compatible before attempting any rewrite.
- **FR-003**: Exercise MUST define a concrete, known sample Dart package as the rewrite target so the exercise is repeatable and its expected output is deterministic.
- **FR-004**: Exercise MUST include a verification step that validates the rewritten package: checks for expected `zfa`-generated files in canonical v5 layout, confirms compilation, and asserts structural correctness.
- **FR-005**: Exercise MUST teach and validate the stop-and-report protocol: when the target is not `zfa`-compatible, the agent must stop before attempting rewrite and produce a structured report.
- **FR-006**: Exercise MUST run in an isolated sandbox (e.g., `.gym/.sandbox/`) and MUST NOT mutate the project source tree.
- **FR-007**: Exercise MUST grade on exit code: exit 0 = pass (whether successful rewrite or correctly-handled incompatibility), exit non-zero = fail.
- **FR-008**: Exercise MUST NOT require or expect the agent to use any tools beyond `zfa` CLI commands for the rewrite task itself (setup/download tools are permitted).

### Key Entities *(include if feature involves data)*

- **GYM Exercise**: A named, runnable training unit in the GYM registry with a brief, setup instructions, a verify command, and a grading rule (exit code). Identified by a unique `id` field.
- **Sample Package**: A concrete Dart package (embedded fixture or referenced repository) that serves as the rewrite target. Must be explicitly identified and fixed per exercise run.
- **Compatibility Assessment**: A step in the exercise that evaluates whether the target package is Zuraffa-compatible (has `zorphy_annotation` or Zuraffa markers) and routes to either the rewrite path or the stop-and-report path.
- **Verification Output**: The structured result of the exercise: rewritten files (if applicable), compilation status, and grading outcome (pass/fail with reasons).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An agent that completes the exercise on a compatible package produces `zfa`-generated output that compiles and matches the canonical v5 layout for all entities.
- **SC-002**: An agent that completes the exercise on a non-compatible package stops before attempting `zfa` rewrite and produces a structured report (exit 0 — correct behavior).
- **SC-003**: The exercise can be run end-to-end by the miki GYM runner (or equivalent) without manual intervention and produces a deterministic grade.
- **SC-004**: The exercise is discoverable in the GYM registry and listed with a clear brief describing what it trains.

## Assumptions

- The GYM registry (`gym.yaml` in `.gym/`) is the authoritative location for exercise definitions in this project, and the miki GYM runner (`gym.mjs` or equivalent) consumes it.
- The `zfa` CLI is installed and functional in the exercise environment; the exercise does not install or configure `zfa` itself.
- The exercise's compatibility-detection step relies on existing Zuraffa markers (e.g., `zorphy_annotation`, `.zfa.json`, `zuraffa` dependency in `pubspec.yaml`) rather than inventing new markers.
- Issue #477 (zfa cannot rewrite the `zikzak_inappwebview` WebView plugin) remains open; this exercise is scoped to completable package types and does not depend on #477's resolution.
- The stop-and-report protocol is the primary fallback for incompatibility; the exercise does not attempt to "fix" non-compatible packages.
- The sample package used as the rewrite target is a simple, well-known Dart package with clear entity definitions (e.g., a basic CRUD-style package) rather than a complex platform plugin.
- This feature lives in the `zuraffa` repository and modifies only `.gym/` and `specs/` directories; no source code changes to `lib/` are required.
