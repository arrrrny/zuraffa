# Feature Specification: Skeleton Plugin — Bare-Bones Feature Scaffold

**Feature Branch**: `020-skeleton-plugin-bones`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "Skeleton plugin: bare-bones feature 'bones' for delegated agent builds"

**Origin**: [GitHub issue #542](https://github.com/arrrrny/zuraffa/issues/542)

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Generate a standalone bone for a single feature (Priority: P1)

A developer or orchestrating agent defines a feature request (via `specify` or
manually) and asks Zuraffa to produce a self-contained "bone" — a minimal scaffold
that captures just that feature's shape: its entity stubs, placeholder layers, and
dependency declarations. A cloud agent receives the bone and builds out the feature
without cloning the full repo.

**Why this priority**: This is the core value proposition. Without the ability to
produce a standalone bone, delegated agents cannot function independently, and the
entire parallel-work workflow is blocked.

**Independent Test**: Run the bone generator for a named feature and verify the
output directory contains a complete, self-contained scaffold: manifest, entity
placeholders, dependency graph, and a buildable entry point. The scaffold compiles
(or type-checks) in isolation with no imports pointing outside itself.

**Acceptance Scenarios**:

1. **Given** a named feature with at least one entity and one method, **When** the
   bone command is invoked, **Then** a directory is created containing a manifest
   file, entity stubs, layer placeholders, and a dependency declaration file.
2. **Given** the generated bone directory, **When** an external agent opens it
   without the parent Zuraffa repo, **Then** it can identify every dependency it
   needs and the structure it must build, without consulting any file outside the
   bone.
3. **Given** a bone that declares a dependency on another bone, **When** the bone
   is generated, **Then** the dependency reference is recorded in the manifest and
   the dependent bone's stub is either included or linked.

---

### User Story 2 — Declare inter-bone dependencies (Priority: P1)

Each bone must know which other bones it depends on so that a multi-feature build
can be assembled in the correct order. The dependency graph is produced
automatically from entity relationships declared in the feature definition.

**Why this priority**: Bones that cannot declare dependencies create ordering
ambiguity when multiple features are delegated in parallel. This is a hard
requirement for the parallel-work workflow described in the issue.

**Independent Test**: Define two features where Feature B references an entity from
Feature A. Generate both bones and verify the dependency graph in B's manifest
lists A. Verify the graph is acyclic (topological sort succeeds).

**Acceptance Scenarios**:

1. **Given** Feature A defines entity `Product` and Feature B references `Product`,
   **When** both bones are generated, **Then** Feature B's manifest declares a
   dependency on Feature A and specifies the shared entity.
2. **Given** a set of bones with a circular dependency, **When** the dependency
   resolver runs, **Then** a clear error is reported indicating the cycle and the
   involved bones.
3. **Given** a bone with no dependencies, **When** it is generated, **Then** the
   manifest contains an empty dependency list.

---

### User Story 3 — Integrate with the existing SDD/TDD workflow (Priority: P2)

The skeleton plugin must compose cleanly with the existing `specify` and `tdd`
plugins. When a feature request is captured via `specify`, the bone generator can
be invoked as the next step to hand off the implementation to an external agent.

**Why this priority**: Seamless integration with the SDD+TDD pipeline is the
stated integration goal in the issue. It enables the "define → scaffold → delegate"
workflow but depends on Stories 1 and 2 being solid first.

**Independent Test**: Run `specify` to define a feature, then invoke the bone
generator on the resulting spec. Verify the bone is produced in the correct format
and can be passed to a delegate agent. Run `tdd` on the bone's test stubs and
confirm the test scaffold is valid.

**Acceptance Scenarios**:

1. **Given** a feature defined via `specify` with a completed spec, **When** the
   bone generator is invoked on that spec, **Then** a bone is produced that
   reflects the spec's entities, methods, and constraints.
2. **Given** a generated bone, **When** the `tdd` plugin is run on its test
   stubs, **Then** the test scaffold is valid and can be expanded by the delegate
   agent.
3. **Given** a feature already processed by `xray`, **When** the bone generator
   runs, **Then** xray overlays or annotations are preserved in the bone output.

---

### User Story 4 — Export a bone for external agent consumption (Priority: P2)

A generated bone must be exportable in a format that a cloud agent can receive
efficiently — not requiring a git clone of the entire repository.

**Why this priority**: The issue specifically calls out that "it should not require
the whole repo to be cloned or granted access." Export is the mechanism that
delivers on this.

**Independent Test**: Generate a bone, export it (e.g., as a compressed archive or
via a transfer mechanism), and verify the exported artifact contains everything
needed for the external agent to build the feature.

**Acceptance Scenarios**:

1. **Given** a generated bone directory, **When** the export command is run,
   **Then** a single transferable artifact is produced containing the full bone
   structure.
2. **Given** the exported artifact, **When** it is received by an external agent
   in a clean environment, **Then** the agent can extract it and begin building
   without additional context from the parent repo.

---

### Edge Cases

- What happens when a bone references an entity that does not exist in any
  existing feature? The generator MUST report a missing-dependency error and refuse
  to produce a partial bone.
- What happens when two features define the same entity name differently? The
  generator MUST detect the conflict and refuse, requiring the developer to
  reconcile the definitions before generating bones.
- What happens when the feature spec is incomplete (e.g., missing entity
  definitions)? The generator MUST validate the spec and report which required
  fields are missing before producing any output.
- What happens when an agent modifies a received bone and later the parent repo
  changes the original feature? The bone MUST include a version or hash reference
  to the spec it was generated from, so staleness can be detected.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST generate a self-contained scaffold directory (a "bone")
  for any named Zuraffa feature.
- **FR-002**: Each bone MUST include a manifest file that declares the feature
  name, its entity stubs, its layer placeholders, and a dependency list.
- **FR-003**: System MUST automatically compute inter-bone dependencies from
  entity cross-references declared in feature definitions.
- **FR-004**: System MUST detect and report circular dependencies at generation
  time, refusing to produce output until the cycle is resolved.
- **FR-005**: System MUST validate that a bone is self-contained — all imports and
  references within the bone resolve to either local stubs or declared dependencies.
- **FR-006**: System MUST produce an exportable artifact (compressed or otherwise
  packaged) that contains the full bone structure for external agent consumption.
- **FR-007**: System MUST integrate with the existing `specify` plugin so that a
  bone can be generated directly from a completed feature spec.
- **FR-008**: System MUST record a spec-version reference in each bone's manifest
  so that staleness can be detected if the upstream spec changes.

### Key Entities

- **Bone**: A self-contained scaffold for a single feature. Contains entity
  stubs, layer placeholders, a manifest, and dependency declarations. Identified
  by feature name.
- **Manifest**: A metadata file within a bone that declares the feature name,
  version, entity list, dependency graph, and spec version reference.
- **Dependency Graph**: An acyclic directed graph recording which bones depend on
  which other bones, derived from entity cross-references.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can generate a bone for any named feature in under 10
  seconds and verify it is self-contained with no external references.
- **SC-002**: A cloud agent receiving a bone can identify all required entities,
  dependencies, and build targets from the bone alone, without accessing the
  parent repository.
- **SC-003**: The bone generator correctly resolves dependency graphs for features
  with up to 20 inter-bone references, reporting cycles in under 5 seconds.
- **SC-004**: Generated bones compose without conflict alongside the `specify`,
  `tdd`, and `xray` plugins — at least 95% of generated bones pass a
  compatibility check on first generation.

## Assumptions

- The existing `specify` and `tdd` plugins are stable and produce well-formed
  feature specs and test stubs that the bone generator can consume.
- Feature definitions include explicit entity declarations and method lists; the
  bone generator does not infer entities from prose descriptions.
- External agents operate in isolated environments with access to the standard
  Zuraffa toolchain but not the parent repository.
- The export mechanism (compressed archive or equivalent) is sufficient for
  cloud-agent handoff; no network-based transfer protocol is required for v1.
- Circular dependency detection is sufficient as a safeguard; automatic cycle
  breaking is out of scope for the initial release.
