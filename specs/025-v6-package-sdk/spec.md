# Feature Specification: v6 Package SDK

**Feature Branch**: `025-v6-package-sdk`

**Created**: 2026-08-28

**Status**: Draft

**Origin**: GitHub issue [#389](https://github.com/arrrrny/zuraffa/issues/389)

**Input**: User description: "v6: package SDK — zfa package create + generators, DDA auto-DI, module & agent codegen in package context. Deliver a v6 package SDK: `zfa package create` plus generators, DDA auto-DI, and module & agent codegen operating in a package context."

## User Scenarios & Testing *(mandatory)*

<!--
  User stories are PRIORITIZED (P1 = most critical). Each is independently
  testable. The "users" here are Zuraffa package authors who build reusable
  packages that contribute entities, datasources, usecases, modules, and agent
  tools to consuming apps.
-->

### User Story 1 - Scaffold a Zuraffa-native reusable package (Priority: P1)

A Zuraffa package author wants to create a reusable, Zuraffa-native package
that follows the standard domain/data layout, includes a module entry point,
and passes static analysis and codegen out of the box — without hand-assembling
directory structures or writing boilerplate configuration.

**Why this priority**: Without a working scaffold command, every other package
capability (generators, DDA, modules, agent tools) requires manual setup and
cannot be reliably discovered or adopted. The scaffold is the entry point for
the entire feature.

**Independent Test**: A developer runs `zfa package create <name>` and obtains
a package that passes static analysis and build-time codegen with zero manual
edits.

**Acceptance Scenarios**:

1. **Given** an empty working directory, **When** the developer runs
   `zfa package create my_pkg`, **Then** a new package directory is created
   with the standard layout (domain, data, module entry point, test harness,
   analysis configuration, and dependency configuration).
2. **Given** the newly created package, **When** the developer runs static
   analysis on it, **Then** it reports zero errors.
3. **Given** the newly created package, **When** the developer runs the
   Zuraffa build/codegen pipeline, **Then** it completes cleanly with no
   generated-code errors.
4. **Given** the newly created package, **When** the developer inspects
   the dependency configuration, **Then** Zuraffa dependencies are present
   with correct version constraints appropriate for v6.

---

### User Story 2 - Generate domain architecture inside a package without app assumptions (Priority: P1)

A package author wants to use Zuraffa's generator to create entities,
repositories, datasources, and use cases inside a reusable package — where
there is no application shell, no application-level service locator, and no
application routes. Instead, the generator emits a **package registrar** that
the consuming app can merge into its own dependency container automatically.

**Why this priority**: This is the core value proposition of the package SDK —
reusable architecture code that plugs into any app without manual wiring.
Without it, package authors must hand-code architecture or work around
app-specific assumptions in the generators.

**Independent Test**: A developer creates an entity inside a generated package,
runs the generator, and verifies that the output contains a package-level
registrar (not an app-level service locator) and that static analysis passes.

**Acceptance Scenarios**:

1. **Given** a Zuraffa-native package created via the scaffold command,
   **When** the developer runs `zfa entity create` and then the Zuraffa
   generator inside that package, **Then** the generated files include
   domain, data, and use case layers — but no application routes, no
   application-level service locator, and no app-specific presentation
   code.
2. **Given** the generated architecture inside the package, **When** the
   developer inspects the DI registration output, **Then** it is a
   package-level registrar (a standalone registration unit that a
   consuming app can merge) rather than direct app-locator lines.
3. **Given** multiple entities generated inside the same package, **When**
   the generator runs, **Then** each entity produces its own registration
   that the package registrar aggregates — no cross-entity ordering
   assumptions.
4. **Given** the generated package with architecture, **When** the
   developer runs the build/codegen pipeline, **Then** it completes
   cleanly with no errors.

---

### User Story 3 - Package-authored datasources and repositories auto-register in consuming apps (Priority: P2)

A consuming app imports a Zuraffa-native package that contains
annotated datasources and repositories. On import, these components
contribute to the consuming app's dependency container **automatically** —
with zero manual registration code in the app.

**Why this priority**: Auto-registration eliminates the most error-prone
step of package adoption and is the mechanism that makes packages truly
plug-and-play. It depends on the scaffold (Story 1) and generators
(Story 2) being in place.

**Independent Test**: A test app imports a package containing a datasource
and a use case. Without any manual registration in the app, the app's
container resolves both components correctly.

**Acceptance Scenarios**:

1. **Given** a package that contains a datasource and a repository
   contributed via the package registrar, **When** a consuming app
   imports that package, **Then** the app's dependency container
   automatically includes the package's datasources and repositories
   without any manual registration line in the app.
2. **Given** two packages that each contribute a datasource, **When** a
   consuming app imports both, **Then** both datasources are present in
   the container with no conflicts and no manual merge logic in the app.
3. **Given** a package contributes a datasource, **When** the consuming
   app does not import the package, **Then** the app's container has no
   reference to that datasource — registration is strictly tied to
   import, not global side effects.
4. **Given** a package with auto-registered components, **When** the
   consuming app starts, **Then** the lifecycle (initialization and
   disposal) of package-contributed components is managed by the
   consuming app's runtime module.

---

### User Story 4 - Package exposes a runtime module that integrates with the engine (Priority: P2)

A package author wants the generated package to include a runtime module
entry point that a consuming Zuraffa app can activate to register the
package's services and lifecycle hooks with the app's engine. The package
participates in engine startup, shutdown, and lifecycle events without the
app needing to know the package's internal details.

**Why this priority**: The module is the lifecycle backbone that ties
auto-registered components (Story 3) to the runtime. Without it, components
are registered but have no managed lifecycle.

**Independent Test**: A test app activates a package's module at startup;
the module's lifecycle hooks (init, ready, dispose) fire in the correct
order, and the app can query whether the module is active.

**Acceptance Scenarios**:

1. **Given** a package that exposes a runtime module, **When** a
   consuming app activates the module during startup, **Then** the
   module's services are registered with the engine and its
   initialization hook runs.
2. **Given** an active package module, **When** the consuming app shuts
   down, **Then** the module's disposal hook runs and resources are
   cleaned up in the correct order.
3. **Given** a package module, **When** the consuming app queries the
   engine for active modules, **Then** the package's module appears in
   the list with a discoverable identifier.
4. **Given** multiple packages each contributing a module, **When** the
   consuming app activates all of them, **Then** each module initializes
   independently without interfering with the others' lifecycle events.

---

### User Story 5 - Generate agent tools inside a package with namespaced discovery (Priority: P3)

A package author wants to use the Zuraffa generator to create agent tools
(AI-use-case tools) inside a reusable package. The tools are generated
with the package name as a namespace, so a consuming app that imports the
package automatically exposes those tools in its agent tool registry
without any app-side code generation.

**Why this priority**: Agent tools are a higher-level capability that
builds on the package scaffold and generators. It is important for the
ZikZak AI program but less critical than the core package lifecycle.

**Independent Test**: A package generates an agent tool; a consuming app
imports the package and the tool appears in the app's tool registry
namespaced as `<package>.<tool>`.

**Acceptance Scenarios**:

1. **Given** a package with a generated agent tool, **When** a consuming
   app imports the package, **Then** the tool is discoverable in the
   app's agent tool registry with a namespace prefix derived from the
   package name (e.g., `my_pkg.do_something`).
2. **Given** two packages each contributing an agent tool with the same
   use-case name, **When** a consuming app imports both, **Then** both
   tools appear in the registry with distinct namespaced identifiers and
   no collision.
3. **Given** a package agent tool, **When** the consuming app does not
   import the package, **Then** the tool is absent from the registry —
   registration is import-scoped.
4. **Given** a package agent tool, **When** the app invokes it, **Then**
   the tool executes with the package's own dependency context (not the
   app's), and returns a result or error in the standard tool response
   format.

---

### User Story 6 - Build pipeline works identically in package and app context (Priority: P3)

A package author wants the Zuraffa build and codegen pipeline to work
identically whether the project is an app or a package — same commands,
same codegen output shape, same configuration surface. The package
maintains its own build configuration that signals package-mode to the
pipeline.

**Why this priority**: Parity prevents the package SDK from becoming a
separate, divergent workflow. It lowers the learning curve and reduces
maintenance burden.

**Independent Test**: A developer runs the same build commands in a
package and in an app, and the pipeline completes cleanly in both with
the correct output shape for each context.

**Acceptance Scenarios**:

1. **Given** a Zuraffa-native package, **When** the developer runs the
   standard build/codegen pipeline, **Then** it completes cleanly and
   emits package-appropriate output (no app routes, no app service
   locator).
2. **Given** a Zuraffa-native package, **When** the developer inspects
   the package's build configuration, **Then** it contains a
   package-shape marker that the pipeline reads to suppress app-specific
   codegen.
3. **Given** the same entity definition, **When** generated in an app
   context versus a package context, **Then** the entity's domain/data
   layers are identical; only the DI registration and presentation layers
   differ (package registrar vs. app locator).
4. **Given** a package with multiple generated entities, **When** the
   build pipeline runs, **Then** all entities are processed in a single
   pass with no manual ordering required.

---

### User Story 7 - Reference package and documentation enable adoption (Priority: P3)

A package author discovers how to build a Zuraffa-native package by
reading a "Writing Zuraffa packages" guide and examining a toy reference
package in the examples directory. The reference package demonstrates
one datasource, one use case, and one agent tool, consumed by a
demo app end-to-end.

**Why this priority**: Documentation and a reference implementation are
essential for adoption but not for functionality. They validate the
feature works end-to-end and provide the onboarding path.

**Independent Test**: A developer follows the guide and reference
package to build and consume a package without consulting any other
source.

**Acceptance Scenarios**:

1. **Given** the "Writing Zuraffa packages" guide, **When** a developer
   follows it step by step, **Then** they produce a working package
   without needing to consult external sources or issue trackers.
2. **Given** the reference package in examples, **When** a developer
   builds it and the demo app consumes it, **Then** the demo app
   resolves the package's datasource and use case via auto-registration
   and can invoke the package's agent tool by its namespaced identifier.
3. **Given** the guide, **When** a developer reaches the section on
   module activation, **Then** it explains how to activate the package's
   module in the consuming app and what lifecycle events to expect.

---

### Edge Cases

- What happens when `zfa package create` is run with a name that already
  exists in the working directory?
- How does the system handle a package that contributes a datasource with
  the same identity as one already registered by the app or another
  package? (Conflict resolution.)
- What happens when a consuming app imports a package but the package's
  Zuraffa dependency version is incompatible with the app's version?
- How does the system handle a package that contributes no entities,
  datasources, or use cases — a module-only package?
- What happens when the build pipeline runs in a directory that looks like
  a package (has package config) but was not created via the scaffold
  command?
- How does the system handle a package that generates agent tools but the
  consuming app does not have an agent tool registry enabled?
- What happens when a package's module initialization fails during the
  consuming app's startup?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a command to create a new
  Zuraffa-native package scaffold with the standard domain/data layout,
  module entry point, test harness, analysis configuration, and correct
  dependency constraints.
- **FR-002**: The package scaffold MUST pass static analysis and the
  Zuraffa build/codegen pipeline with zero manual edits after creation.
- **FR-003**: The generators MUST operate inside a package without emitting
  application-specific artifacts (routes, app service locator, app-level
  presentation code).
- **FR-004**: The generators MUST emit a package-level registrar in place
  of application-level dependency registration — a standalone unit that
  a consuming app can merge into its container.
- **FR-005**: Package-contributed datasources and repositories MUST
  automatically register in a consuming app's dependency container when
  the package is imported — with zero manual registration in the app.
- **FR-006**: The package MUST expose a runtime module entry point that a
  consuming app can activate to register the package's services and
  participate in the engine's lifecycle (init, ready, dispose).
- **FR-007**: The package runtime module MUST be discoverable by the
  consuming app's engine via a stable identifier and MUST initialize and
  dispose independently of other modules.
- **FR-008**: Agent tools generated inside a package MUST be namespaced
  with the package name (e.g., `<package>.<usecase>`) and MUST appear in
  the consuming app's agent tool registry upon import.
- **FR-009**: Agent tools from different packages MUST coexist in the
  consuming app's registry without identity collisions.
- **FR-010**: The build and codegen pipeline MUST work identically in
  package and app context — same commands, same output shape — with a
  configuration marker that suppresses app-specific codegen in package
  mode.
- **FR-011**: A package MUST maintain its own build configuration that
  signals package-mode to the pipeline, ensuring generated output is
  package-appropriate.
- **FR-012**: The package scaffold MUST support generating multiple
  entities, each contributing its own registration to the package
  registrar, processed in a single build pass.
- **FR-013**: The system MUST provide a "Writing Zuraffa packages" guide
  and a toy reference package in examples that demonstrates the end-to-end
  package lifecycle (create, generate, consume).
- **FR-014**: The package scaffold MUST handle the case where the target
  directory or name already exists by producing a clear error and not
  overwriting existing content.
- **FR-015**: The system MUST detect and report dependency version
  incompatibilities between a package and its consuming app at build time
  or at startup.

### Key Entities *(include if feature involves data)*

- **Zuraffa Package**: A reusable, domain-oriented library that follows
  the standard Zuraffa layout (domain, data, module entry point) and
  contributes architecture components to consuming apps via auto-
  registration rather than manual wiring.
- **Package Registrar**: A standalone, import-triggered registration unit
  that declares which datasources, repositories, and use cases the
  package contributes. A consuming app merges registrars from all imported
  packages into its dependency container.
- **Package Runtime Module**: A lifecycle entry point exposed by the
  package that integrates with the consuming app's engine, managing
  initialization, readiness, and disposal of package-contributed services.
- **Package Agent Tool**: An AI-use-case tool generated inside a package,
  namespaced with the package identity, that becomes discoverable in the
  consuming app's agent tool registry upon import.
- **Package Build Configuration**: A configuration surface within the
  package that signals package-mode to the build pipeline, suppressing
  app-specific codegen and emitting package-appropriate output.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can scaffold and pass static analysis on a new
  Zuraffa-native package in under 5 minutes, using only the scaffold
  command and build pipeline — no manual edits, no external references.
  - **Verification**: An end-to-end test creates a package via the
    scaffold command, runs static analysis, and runs the build pipeline.
    All three pass with zero errors and the elapsed time is under 5
    minutes.
- **SC-002**: A consuming app that imports a package with one datasource
  and one use case can resolve both from its dependency container without
  any manual registration code — verified by a test that checks the
  container's resolution of each component after import.
  - **Verification**: A test app imports a generated package, queries
    its container for the package's datasource and use case, and asserts
    both are non-null and of the correct type. No manual registration
    lines exist in the test app's code.
- **SC-003**: At least 90% of the package's generated domain/data layer
  is identical whether the same entity is generated in app context or
  package context — only the DI registration and presentation layers
  differ.
  - **Verification**: A test generates the same entity in both contexts,
    compares the domain and data files byte-by-byte or structurally, and
    asserts ≥ 90% overlap (accounting for expected registration
    differences).
- **SC-004**: The reference package and guide enable a developer to
  build and consume a package end-to-end without consulting external
  sources, confirmed by an independent reviewer following the guide.
  - **Verification**: An automated or manual walkthrough of the guide
    produces a working package consumed by a demo app, with all
    generated components resolving correctly. The walkthrough takes under
    30 minutes from start to working demo.

## Assumptions

- **Builds on Zuraffa v6 module system and DDA/Auto-DI core.** The
  package SDK assumes these foundational systems are available on the
  development branch and provides a higher-level, package-oriented
  interface over them.
- **Package authors are Zuraffa developers.** The primary audience is
  developers already familiar with Zuraffa's entity/repo/usecase model;
  the guide assumes this baseline knowledge.
- **Consuming apps use Zuraffa v6.** The auto-registration and module
  activation mechanisms assume the consuming app runs Zuraffa v6 with
  its dependency container and engine.
- **Agent tools depend on agent codegen infrastructure.** Package-mode
  agent tool generation builds on the agent codegen and registry assembly
  work tracked separately (issues #385, #386); this feature assumes that
  infrastructure is available.
- **Module lifecycle follows engine conventions.** The package runtime
  module's init/ready/dispose lifecycle follows the same conventions as
  the app's own modules — no separate lifecycle model is introduced.
- **Conflict resolution is addressed in planning.** The edge case of
  identity collisions between package-contributed and app-owned
  components is identified here; the exact resolution strategy (error,
  merge, override) is deferred to implementation planning.
- **v1 scope is single-app consumption.** A package consumed by one app
  in one process is the v1 scope. Cross-process or distributed package
  composition is out of scope.
- **Templates and examples ship with the feature.** The guide and
  reference package are deliverables of this feature, not separate
  follow-ups.
