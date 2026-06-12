---
description: "Task list for implementing Declarative UseCase Registration"
---

# Tasks: Declarative UseCase Registration

**Input**: Design documents from `/specs/010-usecase-registration/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- Zuraffa root: `lib/src/`
- Commands: `lib/src/commands/`
- Plugins: `lib/src/plugins/{plugin}/`
- Capabilities: `lib/src/plugins/{plugin}/capabilities/`
- Tests: `test/`

---

## Phase 1: Setup (Understanding Existing Infrastructure)

**Purpose**: Study reference implementations and infrastructure that will be reused

- [ ] T001 Study `DiPlugin.RegisterCapability` in `lib/src/plugins/di/capabilities/register_capability.dart` as the reference pattern for capability registration
- [ ] T002 Study `AppendExecutor` in `lib/src/core/ast/append_executor.dart` and its strategies (`FieldAppendStrategy`, `ConstructorAppendStrategy`, `ImportAppendStrategy`) to understand the append request lifecycle
- [ ] T003 Study `DiCommand` in `lib/src/commands/di_command.dart` for the CLI argument parsing and `GeneratorConfig` construction pattern
- [ ] T004 Study `PresenterPlugin` in `lib/src/plugins/presenter/presenter_plugin.dart` and its `_buildConstructor` method to understand how use case fields + registrations are generated
- [ ] T005 [P] Study `ControllerPlugin.__generateConstructor` in `lib/src/plugins/controller/controller_plugin.dart` to understand how controllers register use cases (if applicable)

---

## Phase 2: Foundational (Shared Utilities)

**Purpose**: Create shared utilities that ALL register capabilities depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T006 Create `lib/src/utils/use_case_name_resolver.dart` with entity name extraction logic:
  - Known verb prefixes list: `Get`, `Create`, `Update`, `Delete`, `Toggle`, `Watch`, `List`, `Resolve`, `Search`, `Fetch`, `Submit`, `Validate`, `Process`, `Generate`, `Import`, `Export`, `Calculate`, `Find`, `Count`, `Send`, `Remove`, `Archive`
  - `extractEntityName(String useCaseName)` method that strips verb prefix + `UseCase` suffix
  - `extractFieldName(String entityName)` method that lowercases first character
  - `buildUseCaseClassName(String entityName)` method that reconstructs the full class name from verb + entity
- [ ] T007 [P] Create `lib/src/utils/register_file_locator.dart` with file discovery logic:
  - `findPresenterFile(String entity, String domain)` → path to `lib/src/presentation/pages/{domain}/{entity_snake}_presenter.dart`
  - `findControllerFile(String entity, String domain)` → path to `lib/src/presentation/pages/{domain}/{entity_snake}_controller.dart`
  - `findStateFile(String entity, String domain)` → path to `lib/src/presentation/pages/{domain}/{entity_snake}_state.dart`
  - `findUseCaseFile(String target, String outputDir)` → scans `lib/src/domain/usecases/` for matching use case file to infer domain
  - `inferDomain(String target, String outputDir)` → delegates to findUseCaseFile and returns domain directory name
- [ ] T008 [P] Create `lib/src/core/ast/builders/append_request_builder.dart` with utilities to construct `AppendRequest` objects:
  - `buildFieldAppendRequest(String source, String className, String fieldSource)` → `AppendRequest` for `AppendTarget.field`
  - `buildConstructorStatementAppendRequest(String source, String className, String statementSource)` → `AppendRequest` for `AppendTarget.constructor`
  - `buildImportAppendRequest(String source, String importLine)` → `AppendRequest` for `AppendTarget.import`
  - `buildRegisterAppendRequests(String source, String className, String fieldName, String useCaseClassName, String importPath)` → returns list of 3 append requests (field + constructor + import) chained together

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Add a Use Case to an Existing Presenter (Priority: P1) 🎯 MVP

**Goal**: Developers can run `zfa presenter register <UseCaseName>` to register a use case in an existing Presenter with a single command.

**Independent Test**: Create a Presenter with 3 registered use cases, run `zfa presenter register GetProduct`, verify the Presenter file now has 4 use cases with the GetProductUseCase field + constructor registration + import, and the file still compiles.

### Implementation for User Story 1

- [ ] T009 [P] [US1] Create `RegisterPresenterCapability` in `lib/src/plugins/presenter/capabilities/register_presenter_capability.dart`:
  - Implements `ZuraffaCapability` with `name = 'register'`
  - `inputSchema` with `target`, `entity`, `domain`, `presenterName`, `dryRun`, `force`, `verbose`
  - `plan()` method that runs in dry-run mode and returns `EffectReport`
  - `execute()` method that runs for real and returns `ExecutionResult`
  - Execution flow: name resolution → file discovery → file parsing → append request building → AppendExecutor execution → file write
- [ ] T010 [P] [US1] Add `RegisterPresenterCapability` to `PresenterPlugin` capabilities list in `lib/src/plugins/presenter/presenter_plugin.dart`
- [ ] T011 [US1] Add `register` subcommand to `PresenterCommand` in `lib/src/commands/presenter_command.dart`:
  - CLI: `zfa presenter register <UseCaseName> [options]`
  - Supports `--domain`, `--entity`, `--presenter-name`, `--dry-run`, `--force`, `--verbose`
  - Delegates to `RegisterPresenterCapability.execute()`

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - Add a Use Case to an Existing Controller (Priority: P1)

**Goal**: Developers can run `zfa controller register <UseCaseName>` to register a use case in an existing Controller with a single command.

**Independent Test**: Create a Controller with 2 direct use case calls, run `zfa controller register CreateProduct`, verify the Controller file now has the CreateProductUseCase field + constructor registration + import, and the file still compiles.

### Implementation for User Story 2

- [ ] T012 [P] [US2] Create `RegisterControllerCapability` in `lib/src/plugins/controller/capabilities/register_controller_capability.dart`:
  - Same pattern as `RegisterPresenterCapability` but targets controller files
  - `inputSchema` with `target`, `entity`, `domain`, `controllerName`, `dryRun`, `force`, `verbose`
  - Uses `findControllerFile()` for file discovery
- [ ] T013 [P] [US2] Add `RegisterControllerCapability` to `ControllerPlugin` capabilities list in `lib/src/plugins/controller/controller_plugin.dart`
- [ ] T014 [US2] Add `register` subcommand to `ControllerCommand` in `lib/src/commands/controller_command.dart`:
  - CLI: `zfa controller register <UseCaseName> [options]`
  - Same options as presenter register but with `--controller-name`

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - State Register (Priority: P2)

**Goal**: Developers can run `zfa state register <FieldName> --type=<Type>` to add a field with copyWith support to an existing State class.

**Independent Test**: Create a State class with 2 fields, run `zfa state register product --type=Product?`, verify the State file now has a `final Product? product;` field and updated `copyWith`, and the file still compiles.

### Implementation for User Story 3

- [ ] T015 [P] [US3] Create `RegisterStateCapability` in `lib/src/plugins/state/capabilities/register_state_capability.dart`:
  - `inputSchema` with `target` (field name), `type` (required), `entity`, `domain`, `stateName`, `dryRun`, `force`, `verbose`
  - Targets state files via `findStateFile()`
  - Builds field source: `final ${Type} ${fieldName};`
  - Builds copyWith entry
  - Appends both using `AppendExecutor`
- [ ] T016 [P] [US3] Add `RegisterStateCapability` to `StatePlugin` capabilities list in `lib/src/plugins/state/state_plugin.dart`
- [ ] T017 [US3] Add `register` subcommand to `StateCommand` in `lib/src/commands/state_command.dart`:
  - CLI: `zfa state register <FieldName> --type=<Type> [options]`
  - Requires `--type`, supports `--domain`, `--entity`, `--state-name`, `--dry-run`, `--force`, `--verbose`

**Checkpoint**: At this point, all per-layer register commands work independently

---

## Phase 6: Batch Register Command (Priority: P2)

**Goal**: Developers can run `zfa register <UseCaseName> --all` to register a use case across all layers simultaneously.

**Independent Test**: Create a full VPC stack (Presenter + Controller + State + DI) with some use cases, run `zfa register GetProduct --all`, verify all 4 layers are updated.

### Implementation for Batch Register Command

- [ ] T018 [US6] Create `RegisterCommand` in `lib/src/commands/register_command.dart`:
  - CLI: `zfa register <UseCaseName> [options]`
  - Layer flags: `--controller` (`-c`), `--presenter` (`-p`), `--state` (`-s`), `--di` (`-d`), `--all` (`-a`)
  - If no layer flags specified, defaults to all 4 layers
  - Delegates to each layer's capability via `PluginRegistry` or direct instantiation
  - Aggregates results and reports per-layer success/failure
  - Layer processing order: DI → Presenter → Controller → State
  - Each layer is independent; failure in one does not block others
- [ ] T019 [P] [US6] Register `RegisterCommand` in the Zuraffa CLI command runner (likely in `lib/src/cli.dart` or `lib/zuraffa.dart`)

**Checkpoint**: Batch registration works end-to-end

---

## Phase 7: User Story 4 - Remove a Use Case (Priority: P3)

**Goal**: Developers can run `zfa presenter unregister <UseCaseName>`, `zfa controller unregister`, `zfa state unregister` to cleanly remove a registered use case or field.

**Independent Test**: Register a use case via `zfa presenter register`, then remove it via `zfa presenter unregister`, verify the file returns to its original state and still compiles.

### Implementation for User Story 4

- [ ] T020 [P] [US4] Add `unregister` subcommand to `PresenterCommand` in `lib/src/commands/presenter_command.dart`:
  - CLI: `zfa presenter unregister <UseCaseName>`
  - Uses `AppendExecutor.undo()` with the same append requests that would be built for registration
  - Reverts field declaration + constructor statement + import
- [ ] T021 [P] [US4] Add `unregister` subcommand to `ControllerCommand` in `lib/src/commands/controller_command.dart`
- [ ] T022 [P] [US4] Add `unregister` subcommand to `StateCommand` in `lib/src/commands/state_command.dart`:
  - CLI: `zfa state unregister <FieldName>`
  - Reverts field + copyWith entry
- [ ] T023 [US4] Add `--undo` / revert flag to `RegisterCommand` or create `zfa unregister` batch counterpart if needed

**Checkpoint**: All user stories implemented and testable

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Formatting, analysis, and documentation updates

- [ ] T024 [P] Run `dart format lib/src/commands/ lib/src/plugins/presenter/capabilities/ lib/src/plugins/controller/capabilities/ lib/src/plugins/state/capabilities/ lib/src/utils/`
- [ ] T025 [P] Run `dart analyze` on the Zuraffa project and fix any warnings in the new files
- [ ] T026 Update CLI help text in `zfa --help`, `zfa presenter --help`, `zfa controller --help`, `zfa state --help` to include the new register/unregister subcommands
- [ ] T027 Update `AGENTS.md` to document the new register commands in the Generation contract section
- [ ] T028 Update `quickstart.md` at `specs/010-usecase-registration/quickstart.md` with any adjustments learned during implementation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — study reference code
- **Phase 2 (Foundational)**: Depends on Phase 1 — BLOCKS all user stories
- **Phase 3 (US1 - Presenter)**: Depends on Phase 2 — can proceed independently of Phases 4-7
- **Phase 4 (US2 - Controller)**: Depends on Phase 2 — can proceed independently of Phases 3, 5-7
- **Phase 5 (US3 - State)**: Depends on Phase 2 — can proceed independently of Phases 3-4, 6-7
- **Phase 6 (Batch)**: Depends on Phases 3, 4, 5 — needs individual capabilities to exist
- **Phase 7 (US4 - Unregister)**: Depends on Phase 2 — can proceed independently of Phases 3-6
- **Phase 8 (Polish)**: Depends on all desired phases being complete

### User Story Dependencies

- **US1 (Presenter Register)**: Depends only on Phase 2 shared utilities
- **US2 (Controller Register)**: Depends only on Phase 2 shared utilities
- **US3 (State Register)**: Depends only on Phase 2 shared utilities
- **US6 (Batch Command)**: Depends on US1, US2, US3 being complete
- **US4 (Unregister)**: Depends only on Phase 2 shared utilities

### Within Each User Story

- Shared utilities first (Phase 2)
- Capability class before CLI integration
- Implementation before testing

### Parallel Opportunities

- All Phase 1 tasks can be done in parallel (reading different files)
- T006, T007, T008 in Phase 2 can be done in parallel (different files, no dependencies)
- The three register capabilities (US1, US2, US3) can be developed in parallel
- T009/T010 vs T012/T013 vs T015/T016 can be done simultaneously
- T020, T021, T022 (unregister commands) can be done in parallel
- All polish tasks marked [P] can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch capability and CLI integration in parallel:
Task: "Create RegisterPresenterCapability in lib/src/plugins/presenter/capabilities/register_presenter_capability.dart"
Task: "Add register to PresenterCommand in lib/src/commands/presenter_command.dart"
```

## Parallel Example: All Three Register Capabilities

```bash
# All three register capabilities can be developed simultaneously:
Task: "Create RegisterPresenterCapability"
Task: "Create RegisterControllerCapability"
Task: "Create RegisterStateCapability"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: US1 (Presenter register)
4. **STOP and VALIDATE**: `zfa presenter register GetProduct` works end-to-end
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Phase 1 + Phase 2 → Foundation ready
2. Add US1 (Presenter register) → MVP: single-layer registration
3. Add US2 (Controller register) → two-layer coverage
4. Add US3 (State register) → full per-layer coverage
5. Add US6 (Batch command) → one-command full stack
6. Add US4 (Unregister) → full lifecycle management

### Parallel Team Strategy

With multiple developers:

1. Phase 2 (Shared utilities) done by 1 developer
2. US1, US2, US3 done in parallel by 3 developers
3. Batch command done after all 3 capabilities are available
4. Unregister commands done in parallel by team members

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- The batch command (Phase 6) is the only phase that depends on multiple user stories

## Completion Status

- [x] T001-T005 -- Understanding phase (implicitly completed during implementation)
- [x] T006 -- UseCaseNameResolver created at lib/src/utils/use_case_name_resolver.dart
- [x] T007 -- RegisterFileLocator created at lib/src/utils/register_file_locator.dart
- [x] T008 -- Append requests built directly in capabilities (no separate builder needed)
- [x] T009 -- RegisterPresenterCapability created
- [x] T010 -- Added to PresenterPlugin
- [x] T011 -- Auto-registered via CapabilityCommand
- [x] T012 -- RegisterControllerCapability created
- [x] T013 -- Added to ControllerPlugin
- [x] T014 -- Auto-registered via CapabilityCommand
- [x] T015 -- RegisterStateCapability created
- [x] T016 -- Added to StatePlugin
- [x] T017 -- Auto-registered via CapabilityCommand
- [x] T018 -- RegisterCommand created at lib/src/commands/register_command.dart
- [x] T019 -- RegisterCommand registered in CLI runner
- [x] T020 -- UnregisterPresenterCapability created
- [x] T021 -- UnregisterControllerCapability created
- [x] T022 -- UnregisterStateCapability created
- [x] T023 -- Batch register exists (unregister via per-layer commands)
- [x] T024 -- dart format completed (0 changes needed)
- [x] T025 -- dart analyze completed (0 issues)
- [x] T026 -- CLI help text updated
- [x] T027 -- AGENTS.md updated with register/unregister section
- [x] T028 -- quickstart.md updated with unregister commands
