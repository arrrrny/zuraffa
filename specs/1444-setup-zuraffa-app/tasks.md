# Tasks: Setup generates ZuraffaApp as root widget

**Input**: Design documents from `/specs/1444-setup-zuraffa-app/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Tests**: TDD workflow active — all behavior tasks are mandatory and driven through the red-green-refactor loop.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- **[behavior: <id>]**: Maps to a test-list.md behavior; mandatory, driven via TDD loop
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify existing test infrastructure and baseline

- [x] T001 Run existing app_shell_command_test.dart and app_shell_builder_test.dart to confirm baseline passes
- [x] T002 Run existing issue_512 regression test to capture current state

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Ensure the app-shell generation path supports ZuraffaApp correctly before wiring it into setup

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T003 [P] [behavior: contract:A1] Verify AppShellBuilder.buildMain contract — call with zuraffaApp=true and confirm output contains ZuraffaApp in test/plugins/app_shell/app_shell_builder_test.dart
- [ ] T004 [P] [behavior: contract:A2] Verify AppShellBuilder.buildMyApp contract — call with zuraffaApp=true and confirm output contains ZuraffaApp in test/plugins/app_shell/app_shell_builder_test.dart

**Checkpoint**: Foundation ready — the ZuraffaApp generation path works standalone; user story implementation can begin

---

## Phase 3: User Story 1 + 3 — Setup generates ZuraffaApp (Priority: P1) 🎯 MVP

**Goal**: `zfa setup` for Flutter projects generates `lib/main.dart` with `ZuraffaApp` as the root widget, with correct configuration (title, debug banner, imports)

**Independent Test**: Run `zfa setup test_app` and verify `lib/main.dart` contains `ZuraffaApp(...)` with title, `debugShowCheckedModeBanner: false`, and correct imports

### Behavior Tests for US1+US3

- [ ] T005 [US1] [behavior: A1] Widget test: setup generates main.dart with runApp(ZuraffaApp(...)) including title, theme, debugShowCheckedModeBanner:false, GlobalKey in test/commands/setup_command_test.dart
- [ ] T006 [US1] [behavior: U1] Unit test: setup for Flutter generates main.dart using ZuraffaApp instead of MaterialApp.router in test/commands/setup_command_test.dart
- [ ] T007 [US1] [behavior: U2] Unit test: generated main.dart imports package:zuraffa_ui/zuraffa_ui.dart in test/commands/setup_command_test.dart
- [ ] T008 [US1] [behavior: U3] Unit test: generated ZuraffaApp receives title, debugShowCheckedModeBanner:false, GlobalKey, theme in test/commands/setup_command_test.dart
- [ ] T009 [US1] [behavior: U4] Unit test: generated my_app.dart is replaced/removed when zuraffaApp=true in test/commands/setup_command_test.dart
- [ ] T010 [US1] [behavior: U7] Unit test: pure Dart setup does NOT generate ZuraffaApp in test/commands/setup_command_test.dart
- [x] T011 [US1] [behavior: A2] Acceptance test: pure Dart setup generates no app shell in test/commands/setup_command_test.dart
- [ ] T012 [US1] [behavior: U9] Unit test: setup refuses when zuraffa_ui is missing from pubspec in test/commands/setup_command_test.dart
- [ ] T013 [US3] [behavior: A6] Widget test: generated ZuraffaApp passes title, debugShowCheckedModeBanner:false, GlobalKey, theme in test/commands/setup_command_test.dart
- [ ] T014 [US1] [behavior: U8] Unit test: generated main.dart compiles cleanly (dart analyze) in test/commands/setup_command_test.dart
- [x] T015 [US1] [behavior: A7] Acceptance test: generated main.dart has no import errors in test/commands/setup_command_test.dart

### Implementation for US1+US3

- [x] T016 [US1] Implement app-shell invocation in SetupCommand.run() — after bootstrap barrels, invoke AppShellCommand generation with zuraffaApp=true in lib/src/commands/setup_command.dart
- [x] T017 [US1] Wire zuraffa_ui dependency preflight into setup flow — surface AppShellException clearly in lib/src/commands/setup_command.dart
- [x] T018 [US1] Ensure setup skips app shell for pure Dart projects (no Flutter widgets) in lib/src/commands/setup_command.dart
- [x] T019 [US3] Add debugShowCheckedModeBanner: false to ZuraffaApp shell generation in lib/src/plugins/app_shell/builders/app_shell_builder.dart (if not already present)

**Checkpoint**: `zfa setup` for Flutter generates a runnable app with ZuraffaApp as root widget

---

## Phase 4: User Story 2 — Backward compatibility (Priority: P2)

**Goal**: `zfa app shell` without `--zuraffa-app` still generates `MaterialApp.router`; `zfa app shell --zuraffa-app` still works for existing projects

**Independent Test**: Run `zfa app shell --force` and verify `MaterialApp.router`; run `zfa app shell --zuraffa-app --force` and verify `ZuraffaApp`

### Behavior Tests for US2

- [ ] T020 [P] [US2] [behavior: U5] Unit test: app shell --zuraffa-app generates ZuraffaApp in test/commands/app_shell_command_test.dart
- [ ] T021 [P] [US2] [behavior: U6] Unit test: app shell without flag generates MaterialApp.router in test/commands/app_shell_command_test.dart
- [x] T022 [US2] [behavior: A5] Acceptance test: app shell without flag preserves MaterialApp.router in test/commands/app_shell_command_test.dart

### Implementation for US2

- [x] T023 [US2] Verify no code changes needed — backward compatibility already implemented via existing --zuraffa-app flag; confirm by running existing tests

**Checkpoint**: All user stories complete — backward compatibility preserved

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Formatting, analysis, and final validation

- [ ] T024 [P] [behavior: U10] Unit test: GoRouter tree remains functional beneath ZuraffaApp via Router.withConfig in test/plugins/app_shell/app_shell_builder_test.dart
- [x] T025 [P] Run dart analyze on changed files: lib/src/commands/setup_command.dart, lib/src/plugins/app_shell/builders/app_shell_builder.dart
- [x] T026 [P] Run dart format lib test to ensure CI formatting passes
- [x] T027 Run full DI plugin test suite: dart test test/plugins/di/ to verify no regressions from prior chore
- [ ] T028 Run quickstart.md validation scenarios end-to-end

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **US1+US3 (Phase 3)**: Depends on Foundational completion
- **US2 (Phase 4)**: Depends on Foundational completion; can run in parallel with Phase 3
- **Polish (Phase 5)**: Depends on all user stories being complete

### User Story Dependencies

- **US1+US3 (P1)**: Can start after Foundational — no dependencies on other stories
- **US2 (P2)**: Can start after Foundational — independent, but logically follows US1

### Parallel Opportunities

- T003 and T004 can run in parallel (contract tests, different methods)
- T005-T015 (behavior tests) can be written in parallel
- T020-T022 can run in parallel (different test cases)
- T024-T026 can run in parallel (different tools)

---

## Implementation Strategy

### MVP First (User Story 1 + 3 Only)

1. Complete Phase 1: Setup (baseline tests)
2. Complete Phase 2: Foundational (verify ZuraffaApp path works)
3. Complete Phase 3: US1+US3 (setup generates ZuraffaApp)
4. **STOP and VALIDATE**: Run quickstart scenario 1
5. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. US1+US3 → `zfa setup` generates ZuraffaApp → Test independently → MVP!
3. US2 → Backward compatibility confirmed → Full delivery
4. Polish → Clean CI → Ship

---

## Notes

- All behavior tasks are mandatory (TDD workflow active)
- US2 backward compatibility is likely already implemented; test tasks verify rather than implement
- The `zfa setup` → `zfa app shell` invocation is the core change; all other tasks support or verify it
