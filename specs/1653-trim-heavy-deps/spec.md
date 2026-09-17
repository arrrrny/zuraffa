# Feature Specification: Lean Core — heavy integrations become opt-in zfa plugins

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `1653-trim-heavy-deps`

**Created**: 2026-09-15

**Status**: Draft

**Origin**: GitHub issue [#1661](https://github.com/arrrrny/zuraffa/issues/1661) — "Trim optional heavy deps (graphql, minio, opentelemetry, ...) out of the core zuraffa package"

**Input**: User description: "Trim optional heavy dependencies (graphql, gql, minio, opentelemetry) out of the core zuraffa package (issue #1661). Adding zuraffa 6.3.0 grew a consumer's pubspec.lock by +439 lines dragging graphql, gql, minio, opentelemetry, protobuf, xml into every consumer, while typical consumers only use the core seams (Result/AppFailure, UseCase, CancelToken, DI container, module lifecycle). The core runtime stays lean; zfa must still be able to ADD these capabilities as opt-in plugins — when a plugin is enabled it must seamlessly run as a zfa command."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A core-only consumer gets a lean dependency graph (Priority: P1)

A developer building a lean package (the dart_curl case: it uses only
Result/AppFailure, UseCase, CancelToken, the DI container, and module
lifecycle) adds the core zuraffa package as a dependency. The resolved
dependency graph contains none of the heavyweight integration packages
(GraphQL stack, S3/minio stack, OpenTelemetry stack) or their exclusive
transitive baggage (protobuf, xml, gql, …). The developer never sees a
+439-line lockfile jump for seams they never import.

**Why this priority**: This is the issue's headline pain — every consumer
of a "lean" package compiles a heavyweight surface today. Without this,
nothing else in the feature matters.

**Independent Test**: Create a fresh empty package, add the core zuraffa
package, resolve dependencies, and inspect the resolved graph: the four
heavy packages and their exclusive transitive deps are absent; the core
public API compiles and its test suite passes.

**Acceptance Scenarios**:

1. **Given** a fresh consumer package, **When** the core zuraffa package
   is added and dependencies are resolved, **Then** the resolved
   dependency graph contains no GraphQL stack package, no S3/minio stack
   package, and no OpenTelemetry stack package.
   **Type**: acceptance
2. **Given** the trimmed core package, **When** its public API is
   compiled and its test suite runs, **Then** everything passes with the
   heavy dependencies absent from the manifest — no broken imports, no
   missing symbols in the core surface (Result/AppFailure, UseCase,
   CancelToken, DI container, module lifecycle, and every non-heavy
   export).
   **Type**: acceptance

---

### User Story 2 - Heavy capabilities remain available, behind an explicit opt-in (Priority: P1)

A developer who DOES use a heavy capability (the GraphQL generation flow,
the S3/minio storage client, telemetry) enables that capability through
zfa. Once enabled, the existing zfa workflows for that capability run
seamlessly — the same commands, the same flags, the same generated
artifacts as before the split. Nothing about the developer's build flow
changes except the one-time enable step, which names the package to add.

**Why this priority**: The split must not orphan existing heavy-surface
users — the maintainer's explicit directive is that zfa keeps delivering
these capabilities, just opt-in instead of mandatory.

**Independent Test**: Enable one capability through zfa in a project,
run that capability's standard zfa workflow end-to-end, and observe it
complete successfully; disable (or never enable) it and observe every
entry point for that capability exit with guidance naming the enable
step instead of crashing.

**Acceptance Scenarios**:

1. **Given** a project with a heavy capability enabled, **When** the
   developer runs that capability's standard zfa workflow, **Then** it
   completes successfully with the same command surface and outputs as
   before the split.
   **Type**: acceptance
2. **Given** a project where a heavy capability is NOT enabled, **When**
   the developer invokes any entry point for that capability, **Then**
   zfa exits with a non-zero code and a message naming the exact enable
   step — no stack traces, no half-generated artifacts.
   **Type**: acceptance

---

### User Story 3 - Discovering and toggling optional capabilities (Priority: P2)

A developer can see, in one place, which optional capabilities exist,
whether each is enabled in the current project, and what enabling costs
(which package gets added). Toggling is idempotent and honest: enabling
an already-enabled plugin is a no-op success; disabling reports what
stays behind.

**Why this priority**: The opt-in model is only usable if the gate is
discoverable and safe; it builds directly on the P1 split.

**Independent Test**: Run the plugin listing in a fresh project (all
optional capabilities reported disabled), enable one, re-run the
listing (that one reports enabled), enable it again (no-op success).

**Acceptance Scenarios**:

1. **Given** a fresh project, **When** the developer lists the optional
   capabilities, **Then** each heavy capability is listed with its
   enabled state and the package it maps to.
   **Type**: acceptance
2. **Given** any project state, **When** the developer enables an
   already-enabled capability, **Then** the command succeeds as an
   explicit no-op without duplicating configuration.
   **Type**: acceptance

---

### Edge Cases

- What happens when a core-only consumer's code references a removed
  heavy export? The upgrade path must be explicit: a documented
  migration note mapping each removed export to its new plugin package,
  and the analyzer must flag the missing symbol (never a silent
  behavior change).
- What happens when a plugin is enabled but its package is missing from
  the project? zfa must detect the gap and name the fix (add the
  package), not fail deep inside generation with an unreadable import
  error.
- What happens to CI consumers that pin the core package version? The
  split ships as a deliberate major-version event with a migration note
  in the changelog.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The core package manifest MUST NOT declare the GraphQL
  stack packages (graphql, gql) as dependencies.
            traces: LeanCorePin
- **FR-002**: The core package manifest MUST NOT declare the S3/minio
  stack package (minio) as a dependency.
            traces: LeanCorePin
- **FR-003**: The core package manifest MUST NOT declare the
  OpenTelemetry stack package (opentelemetry) as a dependency.
            traces: LeanCorePin
- **FR-004**: The core public barrel MUST NOT re-export any symbol from
  the heavy packages or from code that imports them (the GraphQL
  surface, the minio-backed client, the OpenTelemetry api re-export,
  and the telemetry mesh's heavy-backed types move out of the core
  barrel's export closure).
            traces: LeanCorePin
- **FR-005**: zfa MUST provide one command that lists the optional
  capabilities with, per capability: its name, its enabled/disabled
  state for the current project, and the package that backs it.
            traces: LeanCorePin
- **FR-006**: zfa MUST provide an enable action per optional capability
  that records the enablement in the project's zfa configuration and
  prints the package the developer must add (idempotent on re-enable).
            traces: LeanCorePin
- **FR-007**: When a capability is enabled AND its backing package is
  resolvable in the project, the capability's existing zfa workflows
  MUST run seamlessly — same commands, same flags, same outputs as
  before the split.
            traces: LeanCorePin
- **FR-008**: When a capability is not enabled, or is enabled but its
  backing package is not resolvable in the project, every entry point
  for that capability MUST refuse with a non-zero exit and guidance
  naming the exact fix (enable step / package to add) — never a crash
  or partial artifacts.
            traces: LeanCorePin
- **FR-009**: The core seams that heavy code built upon (the telemetry
  hook interface, storage seam interfaces, and the module lifecycle)
  MUST remain in core so plugin packages can implement them — the
  seams are contracts, the heavy implementations are plugins.
            traces: LeanCorePin
- **FR-010**: The changelog MUST document the split as a breaking change
  with a per-export migration map (old core symbol → new plugin
  package).
            traces: LeanCorePin

## Layer Contracts

**Function**:
- `LeanCorePin`: `heavyPackages() -> List<String>`, `isEnabled(String plugin) -> bool`, `enable(String plugin) -> bool`

### Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| OptionalPlugin | `name: String`, `package: String`, `enabled: bool` | one optional capability and the package that backs it |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A fresh consumer adding the trimmed core package resolves a
  dependency graph containing zero occurrences of the four heavy
  packages and zero of their exclusive transitive baggage (the pre-split
  consumer resolution added the heavy stack; post-split it adds none of
  it).
- **SC-002**: The core package's own test suite passes with the heavy
  packages absent from its manifest — zero compile errors, zero missing
  symbols in the retained core surface.
- **SC-003**: With a capability enabled and resolvable, its standard zfa
  workflow completes end-to-end successfully; without it, every entry
  point for that capability exits non-zero with guidance naming the fix
  — measured across all entry points for each of the three capabilities.
- **SC-004**: One listing command reports every optional capability with
  its enabled state and backing package, in under a second on a cold
  run.

## Assumptions

- **Companion topology**: the heavy capabilities move to companion
  packages in the same repository (the federated-plugin family shape the
  repo already scaffolds via `zfa package plugin`), publishable
  independently; whether they later split into separate repos is a
  maintenance decision out of scope here.
- **Breaking change**: dropping the heavy exports from the core barrel
  is a deliberate major-version event; the changelog carries the
  migration map (FR-010).
- **Scope of "..."**: the issue's ellipsis is interpreted as the three
  stacks it names — GraphQL (graphql + gql), storage (minio), and
  observability (opentelemetry). Other heavy-ish dependencies (TUI
  engine, VM service driver, archive, hive sync) stay in core for this
  feature and can follow the same plugin pattern later.
- **Generation-time usage**: where the zfa CLI itself uses a heavy
  package at generation time (e.g. GraphQL schema parsing), that usage
  moves with the capability's plugin so a core-only install never needs
  it — the seamless-enabled path (FR-007) is what keeps the workflow
  working after the move.
- **Existing tests**: suites exercising heavy-backed generation keep
  passing by running against the plugin-enabled configuration; suites
  for core-only behavior must pass without any plugin enabled.
