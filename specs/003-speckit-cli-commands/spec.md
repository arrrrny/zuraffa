# Feature Specification: Implement all ZFA CLI Commands in Zuraffa Speckit Extension

**Feature Branch**: `003-speckit-cli-commands`  
**Created**: 2026-04-17  
**Updated**: 2026-04-26  
**Status**: Draft  
**Input**: User description: "Add zuraffa-speckit as a git submodule and then make a through analysis of all available cli commands and impement them in that speckit extension for zuraffa"

## Clarifications

### Session 2026-04-26

- Q: What is the actual deliverable? → A: Keep the speckit extension approach - create command .md files wrapping ZFA CLI so AI agents use `zfa` commands instead of manually writing files. Test in isolation in a temp folder.
- Q: How should we create the 26 command .md files? → A: Auto-generate from `zfa manifest` JSON output - each plugin command becomes a .md file with its schema as parameters.
- Q: What defines a passing end-to-end test? → A: Full todo app simulation - commands generate valid code that compiles (`flutter analyze` passes) AND a minimal app runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - AI Agent Uses ZFA Extension Commands to Scaffold Features (Priority: P1)

An AI agent (Claude, Cursor, etc.) receives a request like "create me a todo app in Flutter" and uses the speckit extension commands to call `zfa` CLI for every code generation step - entity creation, use case generation, view/controller generation - without manually writing any boilerplate files.

**Why this priority**: This is the core requirement - enabling AI agents to generate complete features using only ZFA CLI through extension commands.

**Independent Test**: Can be tested by scaffolding a complete Todo app in a temp Flutter project using only zfa CLI commands, then verifying the generated code compiles and the app runs.

**Acceptance Scenarios**:

1. **Given** an AI agent and a fresh Flutter project with zuraffa, **When** the agent uses extension commands to create a Todo entity, generate use cases, scaffold views/controllers, **Then** all files are generated via `zfa` CLI without any manual file writing.
2. **Given** a complete feature scaffolded through extension commands, **When** `zfa build` and `flutter analyze` are run, **Then** the code compiles with zero errors.
3. **Given** a complete feature scaffolded through extension commands, **When** the Flutter app is launched, **Then** it runs without runtime errors.

---

### User Story 2 - Auto-Generated Commands from ZFA Manifest (Priority: P2)

The extension commands are auto-generated from `zfa manifest` JSON output, ensuring they always reflect the actual CLI capabilities and stay in sync as ZFA evolves.

**Why this priority**: Auto-generation from manifest eliminates manual drift between extension and CLI.

**Independent Test**: Can be tested by regenerating commands from manifest and verifying all CLI commands are represented.

**Acceptance Scenarios**:

1. **Given** the `zfa manifest` command outputs all plugin commands with schemas, **When** the extension is regenerated, **Then** every plugin command has a corresponding .md file with correct parameter definitions.
2. **Given** a new plugin is added to ZFA CLI, **When** the extension is regenerated from manifest, **Then** the new command appears automatically.

---

### User Story 3 - Organize Commands by Category (Priority: P3)

Commands are organized by category (Generation, Domain, Data, Presentation, Utilities, Testing, Management) for discoverability.

**Why this priority**: With 26+ commands, organization helps AI agents and developers find the right command quickly.

**Independent Test**: Can be tested by verifying commands are grouped and can be located through category navigation.

**Acceptance Scenarios**:

1. **Given** a developer or AI agent, **When** they view command categories, **Then** commands are grouped into logical categories matching the manifest structure.
2. **Given** a developer searching for a specific functionality, **When** they browse by category, **Then** relevant commands appear in the expected group.

---

### Edge Cases

- What happens when zfa is not installed or not in PATH? → Extension should detect and report clearly.
- How does the extension handle commands that require interactive input? → Use `--format=json` for non-interactive output.
- What happens when a command fails due to invalid parameters? → Capture and surface the CLI error output.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The extension MUST auto-generate a command .md file for each plugin command in `zfa manifest` JSON output
- **FR-002**: Each extension command MUST pass through all relevant CLI flags and options as defined in the manifest's inputSchema
- **FR-003**: The extension MUST auto-generate command files from manifest to stay in sync with CLI changes
- **FR-004**: Commands MUST be organized by plugin category (Generation, Scaffolding, Domain, Data, Presentation, etc.)
- **FR-005**: The extension MUST support `--format=json` and `--dry-run` for all generation commands
- **FR-006**: The extension MUST handle error conditions by capturing CLI output and surfacing meaningful messages
- **FR-007**: AI agents MUST be able to scaffold a complete feature (entity, use cases, views, controllers, DI) using only extension commands
- **FR-008**: A generation script MUST exist to rebuild all command .md files from `zfa manifest`

### Key Entities *(include if feature involves data)*

- **ZFA Command**: Represents a CLI command with name, subcommand, flags (from manifest inputSchema), and help text
- **Command Category**: Groups related commands by plugin name (repository, usecase, feature, view, etc.)
- **Command Registry**: Auto-generated mapping from manifest JSON to extension .md files

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All plugin commands from `zfa manifest` are available as extension .md files
- **SC-002**: AI agents can scaffold a complete Todo app using only extension commands (no manual file writing)
- **SC-003**: Generated code passes `flutter analyze` with zero errors
- **SC-004**: Generated Todo app runs without errors
- **SC-005**: Regenerating from manifest produces identical command files (reproducible)

## Assumptions

- The zuraffa-speckit extension framework supports command execution with flags
- ZFA CLI `manifest` command outputs accurate JSON schemas for all plugin commands
- `zfa build` generates entity code before other generation steps
- Developers have zfa accessible via `dart run zuraffa:zfa`
- AI agents will invoke the extension commands which translate to `zfa` CLI calls
- Testing is done in a temp Flutter project in isolation

## Pre-Hook: Project Setup Requirements

These steps MUST be completed before any zfa code generation commands can succeed. AI agents using the extension MUST execute these as a pre-flight check.

### 1. Binary Installation

```bash
dart pub global activate zuraffa
```

Verifies `zfa` is on PATH. If missing, all extension commands will fail.

### 2. Project Dependencies

```bash
flutter pub add zuraffa zorphy_annotation
flutter pub add dev:build_runner
```

### 3. Dependency Overrides (Flutter SDK Compatibility)

Flutter 3.41.x ships `meta 1.17.0` but zuraffa 4.x requires `meta ^1.18.0`, `analyzer ^12.0.0`, and `dart_style ^3.1.8`. Add to `pubspec.yaml`:

```yaml
dependency_overrides:
  meta: ^1.18.0
  analyzer: ^12.0.0
  dart_style: ^3.1.8
```

### 4. build.yaml Configuration

Create `build.yaml` in project root to enable zorphy + json_serializable code generation:

```yaml
targets:
  $default:
    sources:
      exclude:
        - example/**
        - test/fixtures/**
    builders:
      zorphy:zorphy:
        enabled: true
        generate_for:
          - lib/src/**
      json_serializable:
        enabled: true
        generate_for:
          - lib/src/**
        options:
          explicit_to_json: false
          include_if_null: false
          generic_argument_factories: true
      hive_ce_generator:hive_type_adapter_generator:
        enabled: false
      hive_ce_generator:hive_adapters_generator:
        enabled: false
      hive_ce_generator:hive_registrar_intermediate_generator:
        enabled: false
      hive_ce_generator:hive_registrar_generator:
        enabled: false
```

### 5. Entity Must Include `id` Field

All entities used with CRUD methods (`get`, `getList`, `create`, `update`, `delete`) MUST include an `id` field:

```bash
zfa entity create -n Todo --field id:String --field title:String --field isCompleted:bool
```

Without `id`, generated use cases, repositories, and datasources will have compile errors (`The getter 'id' isn't defined`).

### 6. Build Entity Code Before Feature Scaffold

After creating entities, MUST run build before generating features:

```bash
zfa build
```

This generates the `.zorphy.dart` and `.g.dart` files that the feature scaffold depends on.

### Known Issues

- **`toggle` method import path mismatch**: The `toggle` method generates code referencing `{Entity}Field` (e.g., `TodoField`) and expects it at `domain/entities/{entity}_field/{entity}_field.dart`, but `zfa entity enum` creates enums in `domain/entities/enums/`. Additionally, `ToggleParams` is not in `KnownTypes.isExcluded`, causing an incorrect local import. Avoid `toggle` until zfa fixes these paths.
- **First build is slow**: `zfa build` compiles AOT builders on first run (~3min). Subsequent runs are fast (~2s).
