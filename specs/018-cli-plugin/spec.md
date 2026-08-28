# Feature Specification: Native CLI Plugin for Zuraffa

**Feature Branch**: `018-cli-plugin`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "CLI plugin that standardize all zuraffa apps to use same cli interface and cross refererenc, interact and share commands."

## User Scenarios & Testing *(mandatory)*

<!--
  User stories are PRIORITIZED (P1 = most critical). Each is independently
  testable. The "users" here are (a) the Zuraffa app developer building a CLI
  app, and (b) the end user running a Zuraffa CLI app.
-->

### User Story 1 - Build a CLI app with a standardized interface by default (Priority: P1)

A Zuraffa app developer wants to ship a command-line app that automatically
follows Zuraffa's standard CLI contract — uniform command/flag structure, global
flags, help, error messaging, and output formatting — without hand-rolling a
parser or conventions. They declare commands and start the CLI through a single
standardized entry point.

**Why this priority**: Without a standard interface enforced by default, the
"same CLI interface across all Zuraffa apps" goal cannot be met; this is the
floor of the feature.

**Independent Test**: A developer can scaffold a one-command CLI and run it; the
command parses args, prints consistent help, and emits consistent error/output —
with no bespoke parsing or formatting code written by the developer.

**Acceptance Scenarios**:

1. **Given** a Zuraffa app that declares a command via the standard model,
   **When** the developer starts it through the standardized entry point, **Then**
   args are parsed and dispatched to the command handler.
2. **Given** an invoked command, **When** it produces output or an error, **Then**
   the output follows the shared formatting and exit-code conventions.

---

### User Story 2 - End users get a consistent CLI across every Zuraffa app (Priority: P1)

An end user runs different Zuraffa CLI apps and experiences the same command
structure, flag names, help layout, error style, and output shape in all of them,
so they can transfer knowledge from one app to the next without relearning.

**Why this priority**: Consistency for the end user is the explicit, headline
goal ("same CLI interface across all Zuraffa apps"); it is the measure of success.

**Independent Test**: A user can run two independently built Zuraffa CLI apps and
complete equivalent tasks using the same command/flag vocabulary and the same
help/error/output style, confirmed by side-by-side review against the contract.

**Acceptance Scenarios**:

1. **Given** the shared CLI contract, **When** any Zuraffa app renders help or
   errors, **Then** it uses the defined layout, terminology, and exit codes.
2. **Given** a command that fails, **When** it exits, **Then** it returns the
   standardized failure exit code and a consistent error message shape.

---

### User Story 3 - Register commands into a shared command registry (Priority: P2)

A developer registers the app's commands into a shared, discoverable command
registry so commands become known across the Zuraffa app ecosystem, not hidden
inside one binary.

**Why this priority**: The registry is the foundation for cross-referencing,
interacting, and sharing commands (the second half of the feature); without it,
apps cannot find each other's commands.

**Independent Test**: After an app registers a command, another process/app can
enumerate the registry and see that command's name, owner app, and definition.

**Acceptance Scenarios**:

1. **Given** a command declared in an app, **When** the app registers it, **Then**
   the command becomes discoverable in the shared registry with its metadata.
2. **Given** multiple apps, **When** each registers its commands, **Then** the
   registry lists commands from all of them without duplication of identity.

---

### User Story 4 - One app discovers and invokes another app's command (Priority: P2)

A developer builds an app that calls another app's registered command by name
through the registry ("cross-reference / interact") — composing behavior without
taking a hard, compile-time dependency on the other app.

**Why this priority**: Cross-app interaction is a core stated goal; it is what
turns independent apps into a composeable ecosystem.

**Independent Test**: App B can invoke App A's registered command via the registry
and receive its result, with no direct import of App A's internals.

**Acceptance Scenarios**:

1. **Given** App A has registered command `X`, **When** App B invokes `X` by name
   through the registry, **Then** `X` runs and App B receives its output.
2. **Given** the requested command is not registered, **When** an app tries to
   invoke it, **Then** the call fails with a clear "command not found" outcome
   that names the missing command.

---

### User Story 5 - Share and reuse command definitions across apps (Priority: P3)

A developer authors a command once and makes it runnable by other Zuraffa apps
via the standardized interface ("share commands"), so the same command does not
get reimplemented per app.

**Why this priority**: Sharing reduces duplication across the ecosystem and
reinforces the single standard interface; it builds on the registry + interaction
stories.

**Independent Test**: A command definition authored in App A is runnable by App B
through the standardized interface with no per-app reimplementation.

**Acceptance Scenarios**:

1. **Given** a command definition registered by App A, **When** App B consumes it
   through the standard interface, **Then** App B can execute it without rewriting
   its logic.
2. **Given** the same command offered by two apps, **When** a caller references
   it, **Then** the conflict is resolved by an explicit, documented namespacing
   rule rather than silent override.

---

### User Story 6 - Scaffold standardized CLI commands via the generator (Priority: P3)

A developer asks the Zuraffa generator to produce standardized CLI commands
(and an entry point) for an existing entity or use case; the generated commands
are wired to that entity's/use case's existing logic and follow the shared
contract.

**Why this priority**: Generation makes the standard CLI the default for new
Zuraffa apps and removes repetitive boilerplate, but depends on the earlier
stories.

**Independent Test**: A developer runs the generation command for one entity and
gets a runnable, contract-compliant CLI command wired to that entity's existing
use cases.

**Acceptance Scenarios**:

1. **Given** an existing entity with use cases, **When** the developer generates
   its CLI commands, **Then** compliant command(s) are produced and wired to the
   entity's data/use-case layer.
2. **Given** generated commands, **When** they are run, **Then** they follow the
   shared contract (no bespoke parsing/formatting).

---

### Edge Cases

- **Unknown / mistyped command**: The CLI MUST return a consistent "command not
  found" outcome with the standardized exit code and a hint to list available
  commands.
- **Ambiguous / conflicting command names**: When two apps register the same
  command name, the plugin MUST apply a documented namespacing/owner rule and
  MUST NOT silently let one override the other.
- **Referenced command or app missing**: Invoking a command whose owner app or
  definition is not available MUST fail with a clear, named error.
- **Circular command references**: A command chain that references itself (directly
  or transitively) MUST be detected and halted with a clear error, not loop
  infinitely.
- **Version mismatch between sharing apps**: When a command is shared across apps
  at different versions, the plugin MUST surface the mismatch rather than produce
  silently inconsistent behavior.
- **Non-CLI / non-interactive context**: Output MUST remain valid and
  machine-readable (consistent format + exit codes) when stdout is piped or not a
  terminal.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The plugin MUST provide a single standardized entry point that boots
  a Zuraffa CLI application (parse arguments, dispatch to a command, run it, and
  return a consistent exit code).
- **FR-002**: The plugin MUST define and enforce a consistent CLI contract
  (command/flag naming, global flags, help layout, error shape, output format,
  and exit-code conventions) across all Zuraffa CLI apps.
- **FR-003**: The plugin MUST provide a declarative command model (a command has a
  name, arguments, flags, and a handler bound to domain logic) consistent with
  Zuraffa's existing declarative style.
- **FR-004**: The plugin MUST provide a shared command registry where apps
  register commands so they are discoverable across the Zuraffa app ecosystem.
- **FR-005**: The plugin MUST allow one app to discover and invoke another app's
  registered command by name through the registry, without a hard compile-time
  dependency on the other app.
- **FR-006**: The plugin MUST allow command definitions to be shared and reused
  across apps via the standardized interface, with no per-app reimplementation.
- **FR-007**: The plugin MUST integrate with Zuraffa's domain layer (entities,
  repositories, use cases) and dependency injection so commands bind to existing
  use cases rather than duplicating logic.
- **FR-008**: The plugin MUST emit consistent, machine-readable output (uniform
  format and exit codes) so commands compose in scripts and pipelines.
- **FR-009**: The plugin MUST handle the edge cases above (unknown/ambiguous
  command, name conflicts/namespacing, missing referenced command/app, circular
  references, version mismatch, non-interactive output).
- **FR-010**: The plugin MUST be distributed as a native, built-in Zuraffa package
  (discoverable and adoptable by any Zuraffa app) rather than a separate
  third-party bolt-on.
- **FR-011**: The plugin MUST support generation of standardized CLI commands and
  entry points for an entity/use case via the Zuraffa generator.
- **FR-012**: The plugin MUST remain pure-Dart compatible so it is usable by
  non-Flutter Zuraffa apps; any CLI surface that requires Flutter MUST be isolated
  to the Flutter layer and never forced on pure-Dart consumers.

### Key Entities *(include if feature involves data)*

- **CLI Application**: The running command-line app — owns the entry point,
  argument parsing, dispatch, and exit behavior.
- **Command**: A standardized, declarative unit (name, arguments, flags, handler
  bound to a use case) that is registered in the shared registry.
- **Command Registry**: The shared, discoverable catalog of commands across apps
  (name → owner app + definition), enabling cross-reference and reuse.
- **CLI Contract**: The standardized conventions (command/flag/help/output/exit
  code) that every Zuraffa CLI app follows.
- **Binding**: The link between a command and Zuraffa domain state/use cases that
  keeps command behavior in sync with the source of truth.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can scaffold and run a first standardized CLI command in
  under 10 minutes from an empty Zuraffa app, using only the standard entry point
  and command model.
- **SC-002**: At least 80% of common CLI surfaces (command, subcommand, flag
  parsing, help, error, output) are consistent across two independently built
  Zuraffa CLI apps, confirmed by side-by-side review against the CLI contract.
- **SC-003**: An app can discover and invoke another app's registered command
  without a hard dependency, measured by a test where App B invokes App A's command
  via the registry (not a direct import).
- **SC-004**: A command authored in one app is runnable by another via the
  standardized interface with no per-app reimplementation (verified across two
  apps).
- **SC-005**: Generated CLI commands require zero manual wiring to the entity's
  existing use cases to run.
- **SC-006**: Output is uniformly machine-readable (consistent format and exit
  codes) so commands compose reliably in scripts and pipelines.

## Assumptions

- **Builds on Zuraffa's existing CLI conventions.** The plugin extends and
  standardizes Zuraffa's current command/argument handling rather than introducing
  a parallel, competing CLI parser.
- **Developer audience.** The primary "user" of the plugin is a Zuraffa
  application developer; end-user consistency (Story 2) is the success measure.
- **Reuses existing architecture.** Commands bind to already-generated
  entities/repositories/use cases and existing DI; the plugin adds a presentation/
  composition layer, not a new data layer.
- **Sharing is at the command-definition level via the registry.** How a command
  actually executes across apps (same process vs. separate process/subprocess) is
  an implementation detail deferred to planning; the contract and registry are
  what enable sharing, independent of transport.
- **Cross-app composition is opt-in and namespaced.** Apps explicitly register and
  reference commands; the registry applies a documented namespacing/owner rule to
  avoid collisions.
- **Defaults over configuration.** The CLI contract ships with sensible defaults;
  per-app overrides are allowed but not required.
- **v1 scope boundaries.** Text/JSON CLI apps only; graphical output, remote
  procedure call transports, and distributed command execution are out of scope
  for v1. The focus is a uniform, composeable CLI surface for Zuraffa apps.
