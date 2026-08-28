# Tasks: Native CLI Plugin for Zuraffa (018-cli-plugin)

**Input**: Design documents from `/specs/018-cli-plugin/` — `spec.md`, `plan.md`.

**Prerequisites**: `plan.md` (required), `spec.md` (required).

**Tests**: Required. The spec specifies measurable success criteria (SC-001…SC-006) with mechanical verification methods; tests are the verification.

**Organization**: Tasks are grouped by user story (US1…US6, matching spec.md), with an MVP-first ordering that delivers US1 + US2 (the standard CLI contract floor) before US3/US4/US5 (registry + cross-app + sharing) and US6 (generator).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1…US6)
- Exact file paths in descriptions

## Path Conventions

- Single project: `lib/src/cli/standard/` for runtime library,
  `lib/src/plugins/cli/` for generator, `test/cli/standard/` for tests.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Spec-kit scaffolding + pubspec hygiene + branch setup.

- [x] T001 Verify token, clone repo, install Dart SDK 3.13.2, install spec-kit + TDD extension
- [x] T002 Initialize spec-kit in clone (non-interactive, zed integration, ignore-agent-tools); install TDD extension from local archive
- [x] T003 Remove `dependency_overrides:` from `pubspec.yaml`; verify `dart pub get` green
- [x] T004 Create branch `feat/018-cli-plugin` from master

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The CLI contract + command model that EVERY user story depends on.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T005 [P] [US1] Define `CliContract` in `lib/src/cli/standard/cli_contract.dart` — exit-code vocabulary (`success=0`, `usage=64`, `runtime=1`, `notFound=2`, `conflict=3`, `versionMismatch=4`, `circularRef=5`), global flag specs (`--help`, `--version`, `--verbose`, `--output=<json|text>`, `--no-color`), error shape schema, output schema. Pure value class. **(FR-002)**
- [x] T006 [P] [US1] Define `StandardCommand` declarative model in `lib/src/cli/standard/command_model.dart` — `name`, `description`, `arguments` (positional), `flags` (named), `handler: Future<CommandResult> Function(Invocation)`. Extends `args.Command<void>` for back-compat with existing `CliRunner`. **(FR-003)**
- [x] T007 [US1] Define `CliApp` standardized entry point in `lib/src/cli/standard/cli_app.dart` — wraps `CommandRunner<void>`, accepts a `CommandRegistry`, exposes `Future<int> run(List<String> args)` returning the contract exit code. **(FR-001, FR-008)**

**Checkpoint**: Foundation ready — `CliContract`, `StandardCommand`, `CliApp` types exist and pass `dart analyze`. User-story implementation can now begin.

---

## Phase 3: User Story 1 + 2 — Standardized CLI Interface (Priority: P1) 🎯 MVP

**Goal**: A developer can scaffold a one-command CLI through `CliApp` and the end user sees a consistent CLI surface.

**Independent Test**: `test/cli/standard/scenarios/sc_001_scaffold_test.dart` builds an empty `CliApp`, registers one `StandardCommand`, runs it, asserts handler invocation + exit code + stdout shape.

### Tests for User Story 1 + 2 (write FIRST, ensure they FAIL)

- [x] T008 [P] [US1] `test/cli/standard/cli_contract_test.dart` — exit codes match contract; global flag specs are non-empty; error shape has required fields (`code`, `message`, `details`).
- [x] T009 [P] [US1] `test/cli/standard/command_model_test.dart` — `StandardCommand` parses args, exposes parsed values via `Invocation`, dispatches to handler exactly once.
- [x] T010 [P] [US2] `test/cli/standard/cli_app_test.dart` — `CliApp.run([])` shows help and exits 0; `CliApp.run(['--version'])` shows version and exits 0; `CliApp.run(['--help'])` shows help and exits 0.
- [x] T011 [P] [US2] `test/cli/standard/scenarios/sc_001_scaffold_test.dart` — SC-001 acceptance: empty app + one command + run → handler invoked once, exit code 0, stdout is valid JSON when `--output=json`.

### Implementation for User Story 1 + 2

- [x] T012 [US1] Implement `CliContract` and its `success`/`usage`/`runtime`/`notFound`/`conflict`/`versionMismatch`/`circularRef` exit-code getters in `lib/src/cli/standard/cli_contract.dart`.
- [x] T013 [US1] Implement `StandardCommand` extending `args.Command<void>`; expose parsed `Invocation` to handler in `lib/src/cli/standard/command_model.dart`.
- [x] T014 [US1] Implement `CliApp.run(args)` returning `Future<int>`; route `--help` / `--version` / `--output` / `--verbose` through the contract; default to exit 0 on success, 64 on usage error in `lib/src/cli/standard/cli_app.dart`.
- [x] T015 [US2] Implement help layout matching the existing `CliRunner._printHelp()` style (USAGE / CORE COMMANDS / OPTIONS sections) inside `CliApp`.
- [x] T016 [US2] Implement error-shape emission (`{code, message, details}`) when a command throws or args fail to parse, with `--output=json` emitting JSON to stderr and `--output=text` emitting the existing `❌`-prefixed format.

**Checkpoint**: SC-001 provable, SC-002 partially provable (consistency floor established).

---

## Phase 4: User Story 3 — Shared Command Registry (Priority: P2)

**Goal**: Apps register commands into a shared registry so commands become discoverable across the ecosystem.

**Independent Test**: `test/cli/standard/command_registry_test.dart` registers two commands from two different apps, enumerates the registry, and sees both with their owner-app metadata and no identity duplication.

### Tests for User Story 3

- [x] T017 [P] [US3] `test/cli/standard/command_registry_test.dart` — register, lookup by `(ownerApp, name)`, enumerate, deduplicate by identity, refuse duplicate `(ownerApp, name)` re-registration.

### Implementation for User Story 3

- [x] T018 [US3] Implement `CommandRegistry` in `lib/src/cli/standard/command_registry.dart` — keyed by `(ownerApp, name)`, `register(StandardCommand)`, `lookup(ownerApp, name)`, `enumerate()`, `enumerateFor(ownerApp)`. Throw `CommandAlreadyRegistered` on duplicate `(ownerApp, name)`.

**Checkpoint**: SC-002 fully provable (registry surface is shared), SC-003 setup ready.

---

## Phase 5: User Story 4 — Cross-App Invocation (Priority: P2)

**Goal**: App B invokes App A's registered command by name through the registry, with NO hard compile-time dependency on App A's internals.

**Independent Test**: `test/cli/standard/scenarios/sc_003_cross_app_test.dart` — AppA registers `greet`; AppB looks up `greet` via the registry, invokes it, asserts the result, and statically does not import AppA's command class.

### Tests for User Story 4

- [x] T019 [P] [US4] `test/cli/standard/cross_app_invoker_test.dart` — invoke by `(ownerApp, name)`, return `CommandResult`, fail with `CommandNotFound` when missing, fail with `ReferencedAppMissing` when owner app is unregistered.
- [x] T020 [P] [US4] `test/cli/standard/scenarios/sc_003_cross_app_test.dart` — SC-003 acceptance: two separate `CliApp` instances, AppB does not import AppA's command class, invocation succeeds via registry.

### Implementation for User Story 4

- [x] T021 [US4] Implement `CrossAppInvoker` in `lib/src/cli/standard/cross_app_invoker.dart` — takes a `CommandRegistry`, exposes `Future<CommandResult> invoke(String ownerApp, String commandName, Invocation args)`. No reference to the host app's command classes; only the registry type.

**Checkpoint**: SC-003 provable.

---

## Phase 6: User Story 5 — Share and Reuse Command Definitions (Priority: P3)

**Goal**: A command authored in AppA is runnable by AppB through the standardized interface with no per-app reimplementation.

**Independent Test**: `test/cli/standard/scenarios/sc_004_share_test.dart` — AppA authors and shares a `StandardCommand`; AppB retrieves the shared definition, binds it to its own DI, runs it, asserts identical behavior.

### Tests for User Story 5

- [x] T022 [P] [US5] `test/cli/standard/shared_command_test.dart` — `SharedCommand` is a `StandardCommand` plus a `version` and `share() / retrieve()` mechanism; sharing at mismatched versions fails with `VersionMismatch`.
- [x] T023 [P] [US5] `test/cli/standard/scenarios/sc_004_share_test.dart` — SC-004 acceptance.

### Implementation for User Story 5

- [x] T024 [US5] Implement `SharedCommand` (extends `StandardCommand`) with a `SemVer version` field and a `share()` method that publishes the definition to a `SharedCommandStore` (an in-memory map on the registry). Implement `retrieve(name, minVersion)` that fails with `VersionMismatch` when the published version is below `minVersion`.
- [x] T025 [US5] Implement `DiBinding` in `lib/src/cli/standard/di_binding.dart` — adapts a `SharedCommand` retrieved from another app to the host app's `GetIt` instance, so the handler can resolve its domain dependencies from the host's DI rather than the publishing app's.

**Checkpoint**: SC-004 provable.

---

## Phase 7: Edge-Case Handling (cross-cutting — applies to FR-009)

**Purpose**: Cover the six edge cases the spec mandates.

### Tests

- [x] T026 [P] [US1] `test/cli/standard/edge_cases_test.dart` — unknown command, ambiguous name, missing referenced app, circular reference (A→B→A), version mismatch, non-interactive (piped stdout).

### Implementation

- [x] T027 Implement `EdgeCase` typed exceptions in `lib/src/cli/standard/edge_cases.dart`: `UnknownCommandException`, `AmbiguousCommandException`, `ReferencedAppMissingException`, `CircularReferenceException`, `VersionMismatchException`, `NonInteractiveContextException`. Each maps to a specific exit code from `CliContract`.
- [x] T028 Wire `CliApp.run` to catch each `EdgeCase` and emit the contract error shape + exit code.

**Checkpoint**: FR-009 fully provable.

---

## Phase 8: User Story 6 — Generator Support (Priority: P3)

**Goal**: `zfa make <Entity>` can produce a contract-compliant CLI command + entry point for that entity's existing use cases.

**Independent Test**: `test/cli/standard/cli_plugin_generator_test.dart` — drive the `CliPlugin` generator against a fixture entity, assert the generated command file imports the entity's use-case class by name and `dart analyze` on the generated file passes.

### Tests

- [x] T029 [P] [US6] `test/cli/standard/cli_plugin_generator_test.dart` — SC-005: generated command requires zero manual wiring.

### Implementation

- [x] T030 [US6] Implement `CliPlugin extends ZuraffaPlugin` in `lib/src/plugins/cli/cli_plugin.dart` — uses `code_builder` to emit a `StandardCommand` subclass that imports the entity's use-case class and binds through the host's `GetIt`. Follows the existing plugin pattern at `lib/src/plugins/<name>/<name>_plugin.dart`.

**Checkpoint**: SC-005 provable, SC-006 already provable from T011.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Wire the new package into Zuraffa's public API, ensure pure-Dart, ensure no `package:flutter` import, run final verification.

- [x] T031 [P] Export the new `standard/` API from `lib/zuraffa.dart` barrel (add `export 'src/cli/standard/standard.dart';` in an appropriate position).
- [x] T032 [P] Verify NO `package:flutter` import anywhere under `lib/src/cli/standard/` or `lib/src/plugins/cli/` (FR-012). Run `grep -rn 'package:flutter' lib/src/cli/standard/ lib/src/plugins/cli/` and assert zero hits.
- [x] T033 Run `dart analyze lib/src/cli/standard/ lib/src/plugins/cli/ test/cli/standard/` and report ACTUAL pass/fail.
- [x] T034 Run `dart test test/cli/standard/` and report ACTUAL pass/fail counts. Flag any pre-existing failures outside the feature scope.
- [x] T035 [P] Write `specs/018-cli-plugin/tdd/cycle-log.md` (append-only red-green-refactor evidence).
- [x] T036 [P] Write `specs/018-cli-plugin/tdd/verification.md` (audit verdict + mutation evidence).
- [x] T037 Commit per-task or per-phase following Conventional Commits (`feat:`, `test:`, `docs:`).
- [x] T038 Push `feat/018-cli-plugin` to `arrrrny/zuraffa` and open PR vs `master`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — completed first.
- **Phase 2 (Foundational)**: Depends on Phase 1. **BLOCKS all user stories.**
- **Phase 3 (US1+US2 MVP)**: Depends on Phase 2. Delivers the floor — SC-001 provable.
- **Phase 4 (US3 Registry)**: Depends on Phase 3 (`StandardCommand` must exist).
- **Phase 5 (US4 Cross-app)**: Depends on Phase 4 (`CommandRegistry` must exist).
- **Phase 6 (US5 Share)**: Depends on Phase 4 + Phase 5.
- **Phase 7 (Edge cases)**: Depends on Phase 3 (exit codes from contract) + Phase 5 (cross-app invoker for circular-reference test).
- **Phase 8 (US6 Generator)**: Depends on Phase 3 (`StandardCommand` model) + Phase 6 (`DiBinding`).
- **Phase 9 (Polish)**: Depends on all above.

### Within Each User Story

- Tests are written FIRST, expected to FAIL (red), then implementation turns them green.
- One behavior per test, phrased as an observable result.
- Commit after each green cycle.

### Parallel Opportunities

- T005, T006 are [P] — different files, can be written in parallel.
- T008, T009, T010, T011 are [P] — independent test files.
- T017, T019, T020, T022, T023, T026, T029 are [P] — independent test files.
- T031, T032 can run in parallel (different files / different operations).

---

## Implementation Strategy

### MVP First (US1 + US2)

1. ✅ Phase 1 Setup
2. ✅ Phase 2 Foundational (`CliContract`, `StandardCommand`, `CliApp`)
3. ✅ Phase 3 US1+US2 implementation
4. **STOP and VALIDATE**: SC-001 + SC-002 acceptance tests green.

### Incremental Delivery

5. ✅ Phase 4 US3 — registry
6. ✅ Phase 5 US4 — cross-app
7. ✅ Phase 6 US5 — sharing + DI
8. ✅ Phase 7 edge cases
9. ✅ Phase 8 US6 — generator
10. ✅ Phase 9 polish

---

## Notes

- All tasks are checked `[x]` only after the corresponding test or verification actually passes. The cycle log (`specs/018-cli-plugin/tdd/cycle-log.md`) is the evidence.
- A task unchecked with its behavior `DONE` on the test list is a completion claim with no evidence; the verify phase (`tdd/verification.md`) flags these.
- Commit convention: Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`, `refactor:`). Each phase is one or more commits.
