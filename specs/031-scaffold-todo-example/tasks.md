# Tasks: Scaffold Todo Example via CLI with Full Test Suite

**Input**: Design documents from `/specs/031-scaffold-todo-example/`

**Prerequisites**: plan.md, spec.md

**Tests**: MANDATORY (tdd.plan) — the feature IS a scaffold-with-tests
contract; spec SC-001..SC-004 demand automated proof that the generated app
compiles, its tests pass, and its analysis is clean. Every behavior in
`tdd/test-list.md` has a verification task below, and each must be observed
in its red state (missing artifacts / failing run) before the scaffold step
that satisfies it runs. Generated use case tests are the inner loop;
`flutter test` / `flutter analyze` / structural assertions are the outer
loop.

**Organization**: Tasks grouped by user story from spec.md. Behavior
markers (`[A1]`, `[U1]`) trace tasks to `tdd/test-list.md`;
`/speckit.tdd.run` ticks tasks by these markers.

**Acceptance-behavior id map** (from spec.md, 1 AC = 1 outer behavior):
US1.AC1→A1, US1.AC2→A2, US1.AC3→A3, US1.AC4→A4, US1.AC5→A5,
US2.AC1→A6, US2.AC2→A7, US3.AC1→A8, US3.AC2→A9, US4.AC1→A10, US4.AC2→A11.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Baseline proof and the example shell every story builds on

- [x] T001 Record the pre-feature baseline: `dart analyze` clean at the
      branch point `d4cf1d06`; no `example/` directory exists at the repo
      root (removed in `b79d5ff3`); record both in `tdd/cycle-log.md`
- [x] T002 [A10] Write the failing structural assertion FIRST: a check that
      `example/lib/src/presentation/` contains the hand-written
      controller/page/presenter/state files and `lib/main.dart` +
      `lib/setup.dart` exist — observe red (nothing exists yet)
- [x] T003 Create the example Flutter shell (Phase A of plan.md):
      `flutter create --platforms=ios,android --project-name example
      example`; pubspec with `zuraffa: path: ../`, `hive_ce`, dev deps
      `build_runner`/`hive_ce_generator`/`mocktail`/`flutter_lints`;
      reference `analysis_options.yaml` + `build.yaml`; `flutter pub get`

## Phase 2: User Story 1 — Generate a Complete Todo Example App via CLI (P1) 🎯 MVP

**Goal**: All architecture code CLI-generated, compiling, tested.

**Independent Test**: From the bare shell, run the `zfa` commands; the
generated suite passes `flutter test` and `flutter analyze` is 0/0.

- [x] T004 [A1] [U1] Run `zfa entity enum -n TodoPriority --value
      low,medium,high` then `zfa entity create -n Todo` with all 8 fields
      (`id:int`, `title:String`, `description:String`, `isCompleted:bool`,
      `priority:TodoPriority`, `tags:List<String>`, `createdAt:DateTime`,
      `completedAt:DateTime`); verify the generated
      `lib/src/domain/entities/todo.dart` declares every field with the
      correct type and the zorphy `@Zorphy` structure (FR-001, FR-006)
- [x] T005 [A2] [U2] Run `zfa make Todo --preset=crud
      --methods=create,get,getList,update,delete,watch,watchList
      --id-field=id --id-field-type=int --test`; verify all seven use case
      files + repository (abstract+impl), datasource (abstract+impl), DI
      wiring, and one test file per use case are generated (FR-002,
      FR-003)
- [x] T006 [A3] [U3] Run `zfa build`; verify build_runner succeeds and
      emits `todo.zorphy.dart` (comparisons/patch/field descriptors), Hive
      type adapters, and `hive_setup.g.yaml` (FR-008, US3 groundwork)
- [x] T007 [A4] [U4] [U5] [U6] [U7] Run `flutter test` in `example/` — all
      generated use case tests pass (SC-002); fix only scaffold-blocking
      gaps found, each as a reported `fix(031):` change (STOP-ON-ROADBLOCK
      applies)
- [x] T008 [A5] Run `flutter analyze` in `example/` — 0 errors, 0 warnings
      (SC-003); same gap-fix protocol as T007

## Phase 3: User Story 2 — Generated Structure Matches the #219 Reference (P2)

**Goal**: Flat layout, zero hand-written domain/data code.

**Independent Test**: Compare `example/lib/src/` tree against the #219
reference layout; confirm domain/data files are CLI-generated.

- [x] T009 [A6] Assert the flat layout: `domain/`, `data/`,
      `presentation/` directly under `example/lib/src/`, entities under
      `domain/entities/` — no deeper nesting than the generators emit
      (FR-004)
- [x] T010 [A7] Assert zero hand-written domain/data code: every file under
      `example/lib/src/domain/` and `example/lib/src/data/` is CLI-
      generated output; hand-written code lives only in presentation +
      `main.dart`/`setup.dart` (SC-001 proof for the architecture layers)

## Phase 4: User Story 3 — Hive Field Indices Match the Entity (P2)

**Goal**: 1:1 field mapping in `hive_setup.g.yaml`.

**Independent Test**: Parse `hive_setup.g.yaml`, compare field names/types
against the Todo entity definition.

- [x] T011 [A8] [A9] Assert `hive_setup.g.yaml` carries an index entry for
      every Todo field (`id`, `title`, `description`, `isCompleted`,
      `priority`, `tags`, `createdAt`, `completedAt`) with the correct
      type, 1:1 — no missing, no extra (FR-005, FR-007)

## Phase 5: User Story 4 — Presentation Layer Remains Hand-Written (P3)

**Goal**: Working presentation reference over generated use cases.

**Independent Test**: Hand-written presentation files exist, compile, and
introduce no analyzer findings beyond the generated baseline.

- [x] T012 [A10] Write `lib/main.dart`, `lib/setup.dart`, and
      `lib/src/presentation/{todo_controller,todo_page,todo_presenter,
      todo_state}.dart` importing only generated architecture files; make
      T002 green (boundary per US4)
- [x] T013 [A11] Re-run `flutter analyze` — the presentation layer adds no
      new errors or warnings beyond the generated baseline (US4.AC2)

## Phase 6: Final Verification & Integration

**Purpose**: Prove the whole and leave the root untouched

- [x] T014 [A4] [A5] Full clean-run proof in `example/`: `flutter test` all
      green (exact pass/fail counts recorded in `tdd/verification.md`) +
      `flutter analyze` 0/0
- [x] T015 Root regression: `dart analyze` at repo root clean +
      `tools/run_tests_chunked.sh` green (record counts; example/ is
      additive — no root behavior changed)
- [x] T016 [A1]-[A11] Cross-artifact check: every SC-001..SC-005 criterion
      maps to recorded evidence in `tdd/verification.md`; commit spec-kit
      artifacts (spec.md, plan.md, tasks.md, tdd/*) with the example app
