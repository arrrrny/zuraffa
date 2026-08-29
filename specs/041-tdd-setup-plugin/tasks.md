# Tasks: TDD-ready `zfa setup` baseline + `zfa tdd` plugin

**Input**: Design documents from `/specs/041-tdd-setup-plugin/`

**Organization**: Tasks grouped by user story. Part 1 (US1 — day-zero baseline) is MVP-first.

## Phase 1: Setup (Plugin Skeleton)

- [x] T001 Create `lib/src/plugins/tdd/tdd_plugin.dart`
- [x] T002 Create `lib/src/plugins/tdd/models/behavior.dart`
- [x] T003 Create `lib/src/plugins/tdd/models/tdd_profile.dart`
- [x] T004 Create `lib/src/plugins/tdd/models/cycle_entry.dart`
- [x] T005 Create `lib/src/plugins/tdd/models/run_state.dart`
- [x] T006 Create `lib/src/commands/tdd_command.dart`
- [x] T007 Register `TddCommand` in `lib/src/cli/cli_runner.dart`
- [x] T008 Create eight subcommand stubs under `lib/src/plugins/tdd/commands/`
- [x] T009 Wire the eight subcommands into `TddCommand`'s constructor
- [x] T010 [P] Model unit tests
- [x] T011 `dart analyze` clean

## Phase 2: Foundational (TDD baseline writers)

- [x] T012 Create `tdd_profile_writer.dart`
- [x] T013 Create `dart_test_yaml_writer.dart`
- [x] T014 Create `smoke_test_writer.dart`
- [x] T015 Create `pubspec_dev_dependencies_patcher.dart`
- [x] T016 Create `tdd_example_writer.dart`
- [x] T017–T021 [P] Writer tests
- [x] T022 `dart test test/cli/writers/tdd/` clean

## Phase 3: User Story 1 — Day-zero TDD baseline from `zfa setup` (P1) 🎯 MVP

- [x] T023–T027 [P] [US1] Setup-command TDD baseline tests
- [x] T028 Add `--tdd-example` flag to `SetupCommand`
- [x] T029 Wire the four writers into `SetupCommand.run()` as step 6
- [x] T030 Wire `TddExampleWriter` when `--tdd-example` is set
- [x] T031 Honor `--dry-run`
- [x] T032 Update "Next steps" footer
- [ ] T033 End-to-end acceptance test (`sc_001_setup_emits_tdd_baseline_test.dart`) — requires `flutter` on PATH; deferred to follow-up PR.

## Phase 4: User Story 2 — `zfa tdd init` (P2)

- [x] T034–T036 [P] [US2] `init_command` tests
- [x] T037 Implement `init_command.dart` (invokes the four writers)
- [x] T038 Misfire-stop wrapper
- [x] T039 End-to-end idempotent test (`tdd_command_smoke_test.dart`)

## Phase 5: User Story 3 — `zfa tdd plan <feature>` (P2)

- [x] T040 [P] [US3] `spec_parser_test.dart`
- [x] T041 [P] [US3] `plan_command_test.dart` (via `tdd_command_smoke_test.dart`)
- [x] T042–T043 ID preservation + no-acceptance-scenarios misfire
- [x] T044 Create `spec_parser.dart`
- [x] T045 Implement `plan_command.dart`
- [ ] T046 End-to-end scenario `sc_003_plan_emits_test_list_test.dart` — deferred.

## Phase 6: User Story 4 — `zfa tdd gen <behavior-id>` (P2)

- [ ] T047–T050 Tests for stub_writer + gen_command
- [ ] T051 `test_writer.dart` (delegates to `lib/src/plugins/test`)
- [ ] T052 `stub_writer.dart` (uses `code_builder`)
- [ ] T053 Implement `gen_command.dart`
- [ ] T054 Scenario `sc_004_gen_emits_failing_test_test.dart`

## Phase 7: User Story 5 — `zfa tdd verify-red` (P2)

- [ ] T055–T057 Tests
- [ ] T058 `runner.dart`
- [ ] T059 `red_classifier.dart`
- [ ] T060 `cycle_log.dart` (already created)
- [ ] T061 Implement `verify_red_command.dart`

## Phase 8: User Story 6 — `zfa tdd make` (P2)

- [ ] T062–T064 Tests
- [ ] T065 Implement `make_command.dart`

## Phase 9: User Story 7 — `zfa tdd refactor` (P3)

- [ ] T066–T068 Tests
- [ ] T069 Implement `refactor_command.dart`

## Phase 10: User Story 8 — `zfa tdd run <feature>` (P2)

- [ ] T070–T073 Tests
- [ ] T074 `run_state.dart` load/save
- [ ] T075 Implement `run_command.dart`
- [ ] T076 Scenario `sc_008_run_advances_states_test.dart`

## Phase 11: User Story 9 — `zfa tdd verify` (P3)

- [ ] T077–T078 Tests
- [ ] T079 `verifier.dart`
- [ ] T080 Implement `verify_command.dart`
- [ ] T081 Scenario `sc_009_verify_emits_audit_test.dart`

## Phase 12: Polish & Cross-Cutting

- [ ] T082–T084 End-to-end scenarios
- [ ] T085 `dart analyze` clean
- [ ] T086 `dart test` clean
- [ ] T087 Update `docs/cli-guide.md`
- [ ] T088 CHANGELOG entry
- [ ] T089 Quickstart validation

## Implementation status of this PR

This PR lands Phase 1 (skeleton), Phase 2 (writers), Phase 3 (US1 setup baseline, T023–T032), Phase 4 (US2 init), and Phase 5 (US3 plan). Phases 6–11 are honest misfire-stop stubs per FR-031: each unimplemented subcommand throws `StateError` with a message naming the missing task IDs, so calling them surfaces an honest "not yet implemented" rather than silent success. The remaining work is tracked in this tasks.md file for follow-up PRs.
