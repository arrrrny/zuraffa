---
feature: 031-scaffold-todo-example
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 11
planned_at: d4cf1d06
updated_at: d4cf1d06
suite_baseline: green
---

# Test List: Scaffold Todo Example via CLI with Full Test Suite

Baseline: `dart analyze` clean at `d4cf1d06` (pre-feature HEAD, branch point
of `031-scaffold-todo-example`). Root fast suite green — 2385 passed / 0
failed across 60 chunk dirs via the chunked runner protocol (see
`tdd/cycle-log.md` Baseline for the five tag-selector-empty chunk dirs).
The list below derives every behavior from `spec.md` US1-US4 acceptance
criteria, FR-001..FR-008, the Edge Cases section, and SC-001..SC-005; the
feature's unit under test is the `zfa` scaffold flow itself, so outer
behaviors are observed through the CLI/app entry points (`zfa entity`,
`zfa make`, `zfa build`, `flutter test`, `flutter analyze`) and the inner
loop is pinned by `example/test/scaffold_contract_test.dart` plus the seven
generated use case test files.

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md` (US1 AC1-5 -> A1-A5, US2 AC1-2 ->
A6-A7, US3 AC1-2 -> A8-A9, US4 AC1-2 -> A10-A11). Each stays red until the
scaffold step that satisfies it has actually run.

| id  | behavior                                                                                                                                                           | traces  | kind    | state   | test                                                                  |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------- | ------- | ------- | --------------------------------------------------------------------- |
| A1  | Given the example shell, when `zfa entity enum` + `zfa entity create` run for Todo's 8 fields, the entity file exists declaring every field with the correct type   | US1.AC1 | example | DONE    | `example/test/scaffold_contract_test.dart` (entity declarations)      |
| A2  | Given the Todo entity, when `zfa make Todo --preset=crud --methods=create,get,getList,update,delete,watch,watchList --test` runs, all use case/repository/datasource/DI/test files exist | US1.AC2 | example | DONE    | `example/test/scaffold_contract_test.dart` (generated file inventory) |
| A3  | Given all scaffolding complete, when `zfa build` runs, it succeeds and emits zorphy part files, Hive adapters, and `hive_registrar.g.yaml` (the hive field-index yaml)                             | US1.AC3 | example | DONE    | `example/test/scaffold_contract_test.dart` (codegen artifacts)        |
| A4  | Given the build succeeded, `flutter test` passes every generated test                                                                                              | US1.AC4 | example | DONE    | `flutter test` (example/) — counts recorded in cycle-log              |
| A5  | Given the tests pass, `flutter analyze` reports 0 errors and 0 warnings                                                                                            | US1.AC5 | example | DONE    | `flutter analyze` (example/) — output recorded in cycle-log           |
| A6  | The generated layout under `example/lib/src/` is flat (`domain/`, `data/`, `presentation/` at src root) matching the #219 reference                                | US2.AC1 | example | DONE    | `example/test/scaffold_contract_test.dart` (layout assertions)        |
| A7  | No hand-written domain or data layer code exists — every `lib/src/domain` and `lib/src/data` file is CLI-generated output                                           | US2.AC2 | example | DONE    | `example/test/scaffold_contract_test.dart` (generator markers)        |
| A8  | `hive_registrar.g.yaml` (the hive field-index yaml) carries an index entry with the correct type for every Todo field                                                                              | US3.AC1 | example | DONE    | `example/test/scaffold_contract_test.dart` (hive indices)             |
| A9  | `hive_registrar.g.yaml` (the hive field-index yaml) field set matches the entity definition 1:1 — no missing, no extra fields                                                                       | US3.AC2 | example | DONE    | `example/test/scaffold_contract_test.dart` (hive 1:1 count)           |
| A10 | Hand-written presentation files exist and compile against the generated architecture                                                                                | US4.AC1 | example | DONE    | `example/test/scaffold_contract_test.dart` (presentation inventory) + `flutter analyze` |
| A11 | The hand-written presentation layer introduces no analyzer findings beyond the generated baseline                                                                   | US4.AC2 | example | DONE    | `flutter analyze` (example/) — deltas recorded in cycle-log           |

## Inner loop: unit behaviors

Grouped by the component from `plan.md` that owns them.

### `example/lib/src/domain/entities/todo.dart` (CLI: `zfa entity create`)

| id  | behavior                                                                                     | traces       | kind    | state   | test                                                             |
| --- | -------------------------------------------------------------------------------------------- | ------------ | ------- | ------- | ---------------------------------------------------------------- |
| U1  | The entity source declares id:int, title/description:String, isCompleted:bool, priority:TodoPriority, tags:List<String>, createdAt/completedAt:DateTime with zorphy `@Zorphy` structure | FR-001, FR-006, FR-007 | example | DONE    | `example/test/scaffold_contract_test.dart` (entity declarations) |
| U2  | Creating an entity whose enum field type has no enum file fails fast with a clear error and writes nothing | Edge-1, FR-006 | example | DONE    | observed CLI run (evidence in cycle-log)                          |

### `example/lib/src/{domain,data}` (CLI: `zfa make --preset=crud --test`)

| id  | behavior                                                                                     | traces       | kind    | state   | test                                                             |
| --- | -------------------------------------------------------------------------------------------- | ------------ | ------- | ------- | ---------------------------------------------------------------- |
| U3  | The scaffold emits one use case file per method (7), repository abstract+impl, datasource abstract+impl, DI wiring, and one test file per use case | FR-002, FR-003, FR-004 | example | DONE    | `example/test/scaffold_contract_test.dart` (file inventory)      |
| U4  | CreateTodoUseCase test: success delegation returns Result.success; repository exception returns Result.failure | FR-003 | example | DONE    | `example/test/src/domain/usecases/create_todo_usecase_test.dart` |
| U5  | GetTodo/GetTodoList tests: success + failure paths per method                                  | FR-003       | example | DONE    | `example/test/src/domain/usecases/get_todo_usecase_test.dart`, `get_todo_list_usecase_test.dart` |
| U6  | UpdateTodo/DeleteTodo tests: success + failure paths per method                                | FR-003       | example | DONE    | `example/test/src/domain/usecases/update_todo_usecase_test.dart`, `delete_todo_usecase_test.dart` |
| U7  | WatchTodo/WatchTodoList tests: stream success + failure paths                                  | FR-003       | example | DONE    | `example/test/src/domain/usecases/watch_todo_usecase_test.dart`, `watch_todo_list_usecase_test.dart` |
| U8  | Re-running the Todo scaffold detects existing files and skips/warns instead of silently corrupting | Edge-5    | example | DONE    | observed CLI run (evidence in cycle-log)                          |

### `zfa build` pipeline (US3 / Edge-3)

| id  | behavior                                                                                     | traces       | kind    | state   | test                                                             |
| --- | -------------------------------------------------------------------------------------------- | ------------ | ------- | ------- | ---------------------------------------------------------------- |
| U9  | build_runner succeeds on the scaffold and emits `.zorphy.dart` parts + Hive adapters + `hive_registrar.g.yaml` (the hive field-index yaml) | FR-008, US3.AC1 | example | DONE    | `example/test/scaffold_contract_test.dart` (codegen artifacts)   |
| U10 | Building before the entity exists fails with a clear error naming the missing artifact        | Edge-3       | example | DROPPED | observed CLI run (evidence in cycle-log)                          |
    ↑ DROPPED: current `zfa build` with 0 entities exits 0 ("wrote 0 outputs") instead of failing — the Edge-3 guard does not exist in the CLI. Not required by SC-001..SC-005; reported in the PR for a follow-up issue.

## Invariants and edge cases still to place

None — the spec's five edge cases are placed: Edge-1 -> U2, Edge-2 ->
U1/U9 (`List<String>` adapter + comparison inference is asserted as part of
the entity declarations and build artifacts), Edge-3 -> U10, Edge-4 ->
U1/U9 (nullable-aware handling is covered by the `DateTime` field
declarations and emitted Hive indices), Edge-5 -> U8.

## Out of scope

- Presentation/UI generation by the CLI: explicitly out of scope per spec
  US4 and Assumptions — presentation stays hand-written (A10/A11 pin the
  boundary).
- Android/iOS build pipelines for the example: the spec's success criteria
  stop at `flutter test` + `flutter analyze` on the host; no device build.
- Root-package behavior changes: this feature is additive (`example/` +
  spec artifacts); root regressions are guarded by the T015 chunked-suite
  run, not new root tests.
- Performance benchmarks: the spec defines no performance success criteria.

## Verification commands

Copied from `.specify/memory/tdd-profile.md` (root) plus the feature's
Flutter scope (example/ is a Flutter package; the profile's `dart test`
commands do not reach it):

- Root single test: `dart test <file> --plain-name "<name>"`
- Root suite (disk-safe): `tools/run_tests_chunked.sh` (never a single
  whole-tree `dart test` on disposable agents)
- Root analysis: `dart analyze`
- Example test file: `cd example && flutter test <file>`
- Example suite: `cd example && flutter test`
- Example analysis: `cd example && flutter analyze`
- Mutation: no mutation tool wired (profile) — deliberate-mutant sampling
  per the TDD rubric for `tdd/verification.md`
