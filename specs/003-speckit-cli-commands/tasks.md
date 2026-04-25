---

description: "Task list for implementing ZFA CLI commands in zuraffa-speckit extension"
---

# Tasks: Implement all ZFA CLI Commands in Zuraffa Speckit Extension

**Input**: Design documents from `/specs/003-speckit-cli-commands/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Not requested for this feature - extension tests will be manual integration with CLI

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare extension submodule for command additions

- [X] T001 Verify submodule at .specify/extensions/zuraffa is properly initialized
- [X] T002 Create commands/ directory structure in .specify/extensions/zuraffa/commands/
- [X] T003 [P] Create category subdirectories: generation/, scaffolding/, domain/, data/, presentation/, utilities/, testing/, management/, structure/
- [X] T004 [P] Backup existing extension.yml before modifications

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T005 Create command registry schema in .specify/extensions/zuraffa/commands/registry.yaml
- [X] T006 [P] Create base command template for .specify/extensions/zuraffa/commands/_template.md
- [X] T007 Update extension.yml to include new commands section (depends on T005)
- [ ] T008 Create help text cache structure in .specify/extensions/zuraffa/commands/help/

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Add All Core ZFA Commands to Speckit Extension (Priority: P1) 🎯 MVP

**Goal**: All 26 ZFA CLI commands are available through the extension with full flag support

**Independent Test**: Invoke each command through extension and verify output matches direct CLI execution

### Implementation for User Story 1

- [ ] T009 [P] [US1] Create generate.md command file in .specify/extensions/zuraffa/commands/generation/
- [ ] T010 [P] [US1] Create make.md command file in .specify/extensions/zuraffa/commands/generation/
- [ ] T011 [P] [US1] Create initialize.md command file in .specify/extensions/zuraffa/commands/generation/
- [ ] T012 [US1] Create feature.md command file with subcommands in .specify/extensions/zuraffa/commands/scaffolding/
- [ ] T013 [P] [US1] Create usecase.md command file in .specify/extensions/zuraffa/commands/domain/
- [ ] T014 [P] [US1] Create service.md command file in .specify/extensions/zuraffa/commands/domain/
- [ ] T015 [P] [US1] Create provider.md command file in .specify/extensions/zuraffa/commands/domain/
- [ ] T016 [US1] Create repository.md command file in .specify/extensions/zuraffa/commands/data/
- [ ] T017 [US1] Create datasource.md command file in .specify/extensions/zuraffa/commands/data/
- [ ] T018 [P] [US1] Create view.md command file in .specify/extensions/zuraffa/commands/presentation/
- [ ] T019 [P] [US1] Create controller.md command file in .specify/extensions/zuraffa/commands/presentation/
- [ ] T020 [P] [US1] Create presenter.md command file in .specify/extensions/zuraffa/commands/presentation/
- [ ] T021 [P] [US1] Create state.md command file in .specify/extensions/zuraffa/commands/presentation/
- [ ] T022 [P] [US1] Create observer.md command file in .specify/extensions/zuraffa/commands/presentation/
- [ ] T023 [P] [US1] Create route.md command file in .specify/extensions/zuraffa/commands/presentation/
- [ ] T024 [US1] Create cache.md command file in .specify/extensions/zuraffa/commands/utilities/
- [ ] T025 [P] [US1] Create manifest.md command file in .specify/extensions/zuraffa/commands/utilities/
- [ ] T026 [P] [US1] Create validate.md command file in .specify/extensions/zuraffa/commands/utilities/
- [ ] T027 [P] [US1] Create config.md command file in .specify/extensions/zuraffa/commands/utilities/
- [ ] T028 [P] [US1] Create test.md command file in .specify/extensions/zuraffa/commands/testing/
- [ ] T029 [P] [US1] Create mock.md command file in .specify/extensions/zuraffa/commands/testing/
- [ ] T030 [P] [US1] Create apply.md command file in .specify/extensions/zuraffa/commands/management/
- [ ] T031 [P] [US1] Create plugin.md command file in .specify/extensions/zuraffa/commands/management/
- [ ] T032 [P] [US1] Create doctor.md command file in .specify/extensions/zuraffa/commands/management/
- [ ] T033 [P] [US1] Create shadcn.md command file in .specify/extensions/zuraffa/commands/management/
- [ ] T034 [P] [US1] Create create.md command file in .specify/extensions/zuraffa/commands/structure/
- [ ] T035 [P] [US1] Create entity.md command file in .specify/extensions/zuraffa/commands/structure/
- [ ] T036 [US1] Update extension.yml provides section with all 26 commands (depends on T007, T009-T035)

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - Organize Commands by Category (Priority: P2)

**Goal**: Commands are logically grouped for discoverability with category navigation

**Independent Test**: Search for functionality by category and verify correct commands appear

### Implementation for User Story 2

- [X] T037 [P] [US2] Create category index files for each category directory
- [X] T038 [P] [US2] Add category tags to each command file
- [X] T039 [US2] Create category navigation index in .specify/extensions/zuraffa/commands/index.md
- [X] T040 [P] [US2] Add aliases for common command patterns (e.g., zfa.generate as alias for generate)
- [X] T041 [US2] Document categories in quickstart.md update

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - Maintain Feature Parity with ZFA CLI (Priority: P3)

**Goal**: Extension stays synchronized with ZFA CLI updates automatically

**Independent Test**: Add new command to CLI and verify it appears in extension after regeneration

### Implementation for User Story 3

- [X] T042 [P] [US3] Create command discovery script to extract all zfa commands
- [X] T043 [P] [US3] Create flag parser that extracts --help output for each command
- [X] T044 [US3] Create regenerate script to update extension from ZFA CLI
- [X] T045 [US3] Add auto-discovery configuration to extension.yml
- [X] T046 [US3] Document regeneration process in extension README

**Checkpoint**: All user stories should now be independently functional

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [X] T047 [P] Verify all 26 commands execute correctly via extension interface
- [X] T048 Validate help output matches CLI --help for each command
- [X] T049 [P] Update extension README with complete command reference
- [X] T050 Run full integration test against all commands
- [X] T051 Clean up temporary files and backup files

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Adds organization on top of US1 commands
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Adds auto-sync capability on top of US1 commands

### Within Each User Story

- Foundation phase before user stories
- Command files can be created in parallel (T009-T035)
- Extension.yml update after all commands created

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- Once Foundational phase completes, all user story tasks marked [P] can run in parallel
- 26 command file creations (T009-T035) can all run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch all command files for User Story 1 together (26 files):
Task: "Create generate.md command file in .specify/extensions/zuraffa/commands/generation/"
Task: "Create feature.md command file with subcommands in .specify/extensions/zuraffa/commands/scaffolding/"
Task: "Create usecase.md command file in .specify/extensions/zuraffa/commands/domain/"
Task: "Create repository.md command file in .specify/extensions/zuraffa/commands/data/"
Task: "Create view.md command file in .specify/extensions/zuraffa/commands/presentation/"
# ... (all 26 commands in parallel)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 - Core 26 commands
4. **STOP and VALIDATE**: Test all 26 commands independently
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
5. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: Create generation/scaffolding commands (T009-T012)
   - Developer B: Create domain commands (T013-T015)
   - Developer C: Create data commands (T016-T017)
   - Developer D: Create presentation commands (T018-T023)
   - Developer E: Create utilities/testing/management commands (T024-T035)
3. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- This extension wraps ZFA CLI - no new code, just configuration files