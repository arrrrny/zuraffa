# Cycle Log: Scaffold Todo Example via CLI with Full Test Suite

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Baseline

- suite: chunked fast-suite protocol (per-chunk `dart test <dir>
  --exclude-tags flutter` with kernel-cache cleaning, replicating
  `tools/run_tests_chunked.sh` chunking) on `031-scaffold-todo-example` at
  branch point `d4cf1d06` (pre-feature work)
  -> **2385 passed, 0 failed** across 60 chunk dirs.
  Pre-existing runner quirk (NOT caused by this feature, flagged per
  protocol): 5 chunk dirs — `test/benchmark`, `test/core/dependencies`,
  `test/integration`, `test/plugins/tdd/scenarios`, `test/property` — exit
  non-zero with "No tests match the requested tag selectors" / "No tests
  ran." because every test file in them is tagged
  `slow`/`benchmark`/`integration`/`property`, which the runner excludes —
  zero actual test failures. Reproduced manually per dir with
  `dart test <dir> --exclude-tags flutter`.
- analyze: `dart analyze` -> "No issues found!"
- state: no `example/` directory at repo root (removed in `b79d5ff3`); the
  feature recreates it
- commit: `d4cf1d06` (branch point, master)
- recorded: cycle 0, before any change

## Cycle 1: T002 — contract test written FIRST, entire scaffold observed RED

- test: `example/test/scaffold_contract_test.dart` (new, 16 assertions across
  8 groups — entity, inventory, codegen artifacts, flat layout, generator
  markers, hive indices, presentation inventory, generated test inventory)
- red: `flutter test` (example/) -> **1 passed, 15 failed**. Failure modes:
  "zfa entity create -n Todo must emit lib/src/domain/entities/todo/todo.dart"
  (canonical red for a not-yet-generated module), "missing
  lib/src/domain/usecases/todo/create_todo_usecase.dart", "no DI registration
  emitted anywhere", "hive_registrar.g.dart must be emitted", "missing
  lib/main.dart". Nothing had been scaffolded when the test was written.
- note (test amendment before any green was claimed): the initial test pinned
  a flat `entities/todo.dart` path from the #219 reference; the current
  zorphy 2.3.1 EntityCreator + zuraffa v5 `ZfaConfig.fixedEntityOutput` +
  AGENTS.md "Fixed layout assumptions" all mandate
  `entities/<snake>/<snake>.dart`, so the test was amended to the
  generator-canonical path and the A6 depth check tightened accordingly.
- green: delivered by cycles 2-6 below
- commit: pending (single feature commit per repo convention)

## Cycle 2: T003 — example shell, entity CLI steps U1; U2/U10 edge evidence

- U10 (Edge-3) observed FIRST: `zfa build` on the bare shell (0 entities)
  -> exits **0**, prints "Entities: 0, Dart files: 0" and "wrote 0 outputs",
  then "✅ Build completed successfully". The spec's Edge-3 ("should fail
  with a clear error naming missing artifacts") is NOT the current CLI
  behavior — recorded as a found gap, not worked around; U10 marked DROPPED.
- U2 (Edge-1) observed: `zfa entity create -n Todo --field priority:TodoPriority ...`
  BEFORE the enum exists -> exit 1, "❌ Cannot create entity "Todo": field
  type(s) could not be resolved. • Unknown type "TodoPriority" ... Create the
  enum/entity first ... No files were written." Clear error + zero files = PASS.
- green (partial): `zfa entity enum -n TodoPriority --value low,medium,high`
  -> `lib/src/domain/entities/enums/todo_priority.dart` (+ index.dart barrel);
  `zfa entity create -n Todo` with all 8 fields -> `entities/todo/todo.dart`
  with every field correctly typed and `@Zorphy(generateJson: true,
  generateCompareTo: true)`.
- red run #2: `flutter test` -> **3 passed, 13 failed** (entity group green,
  everything else still red).
- CLI gap #2 found en route: the entity command requires `zorphy_annotation:`
  declared in the target pubspec (transitive-through-zuraffa was insufficient)
  — added to example/pubspec.yaml, no root change.

## Cycle 3: T005 — `zfa make --preset=crud --test` (32 files) + TestBuilder gaps

- green: `zfa make Todo --preset=crud
  --methods=create,get,getList,update,delete,watch,watchList --id-field=id
  --id-field-type=int --test` -> 32 files: 7 use cases
  (`lib/src/domain/usecases/todo/`), abstract repository, `data_todo_repository.dart`,
  datasource abstract + remote impl, 11 DI files (`lib/src/di/**` +
  `service_locator.dart`), 7 use case test files (`test/domain/usecases/todo/`).
- red run #3: contract test -> **7 passed, 9 failed** (inventory green, codegen
  + hive + presentation still red); generated use case tests could not compile
  until build (missing part files).
- CLI gap #3 (placeholder writer, zfa make --test without --mock): the test
  plugin's `_ensureNativeMockInfra` emitted
  `class TodoMockDataSource implements TodoDataSource {}` with NO import ->
  `implements_non_class` ERROR in the generated file; it also emitted
  `static dynamic sampleTodo = null` (avoid_init_to_null info). Root cause:
  `lib/src/plugins/test/test_plugin.dart` `_nativeMockPlaceholder()` writes a
  reference to a class from another library without importing it. Also, the
  mock generator SKIPS existing files, so a placeholder can never be repaired
  without `--force`. Reported; the scaffold proceeds on the documented
  `--mock` path (placeholder file deleted, `make --mock --force` re-run).

## Cycle 4: T006 — `zfa build` codegen + generator fixes (fix(031))

- first `zfa build` run exposed missing json part (`todo.g.dart`): the
  example needed `json_serializable` enabled in build.yaml + declared deps
  (json_annotation/json_serializable), mirroring the root build.yaml config.
- zuraffa generator fixes required for the scaffold to compile (all in the
  test/mock/cache writers; each verified against the existing plugin suites):
  1. `mock_entity_helper.dart`: enum-typed fields added an unused
     `<enum>_mock_data.dart` import to generated mock data -> `unused_import`
     warning in every generated mock file with an enum field. Fixed: enums
     resolve through the enums barrel; their mock data file is never
     referenced. 37/37 `test/plugins/mock/` tests pass.
  2. `mock_value_builder.dart`: list-of-string seeded values emitted
     `'item ' + seed.toString()` -> `prefer_interpolation_to_compose_strings`
     infos. Fixed: emits `'item $seed'` interpolation.
  3. `test_builder_entity.dart` (5 emission defects):
     - `Success<$e>` -> `Success<$e, AppFailure>` (Success takes 2 type
       params; the old emission was a compile ERROR —
       wrong_number_of_type_arguments — in every generated watch test);
     - stream value type for `watchList` is `List<Todo>`, not `Todo`;
     - stream failure path: `emitsError(isA<Object>())` contradicted the
       StreamUseCase contract (errors are wrapped into `Failure` Result
       values, then the stream completes) -> `emits(isA<Failure<...>>())`;
     - `toggle` (and any unrequested method) no longer emitted on the
       throwing fake datasource -> removes
       `override_on_non_overriding_member`;
     - abstract repository import + `t<entity>`/mock-data import no longer
       emitted where unused -> removes `unused_import` /
       `unused_local_variable`. 5/5 `test_builder_test.dart` pass after
       updating its pinned `emitsError` expectation to the framework
       contract.
  4. `cache_builder_registrar.dart`: enum fields need the enums barrel
     imported into `hive_registrar.dart` — the generated
     `hive_registrar.g.dart` part casts enum fields (`as TodoPriority`)
     and previously failed with `cast_to_non_type`.
- green: `zfa build` -> exit 0, "No issues found" on lib/, artifacts present:
  `todo.zorphy.dart` (comparisons/copyWith/patch), `todo.g.dart`,
  `lib/src/cache/hive_registrar.dart` + `hive_registrar.g.dart` +
  `hive_registrar.g.yaml`.
- U8 (Edge-5) observed: re-running the identical `zfa make` (no --force)
  -> "Created: 0, Overwritten: 13 (DI, deterministic), Skipped: 21" —
  existing architecture files skipped, content unchanged (md5 verified),
  no corruption. PASS.

## Cycle 5: T012 — hand-written presentation (US4 boundary)

- files: `lib/main.dart`, `lib/setup.dart`,
  `lib/src/presentation/{todo_state,todo_presenter,todo_controller,todo_page}.dart`
  — import ONLY generated artifacts (7 use cases, Todo/TodoPriority/AppFailure,
  generated DI `setupDependencies`, GetIt). Presenter resolves all seven use
  cases from get_it; controller is a ChangeNotifier over TodoState; page is
  Material.
- green: full suite -> **30 passed, 0 failed** (14 generated use case tests +
  16 contract assertions); `flutter analyze` -> "No issues found!" (0 errors,
  0 warnings, 0 infos).

## Cycle 6: T014/T015 — mutation sampling + root regression

- deliberate-mutant sampling (per tdd-profile: no mutation tool wired):
  - mutant 1: `CreateTodoUseCase.execute` -> `throw Exception("MUTANT")`
    -> `create_todo_usecase_test.dart` 1 failed / 1 passed -> mutant KILLED;
    reverted -> 2 passed.
  - mutant 2: `WatchTodoUseCase.execute` -> `throw Exception("MUTANT")`
    -> `watch_todo_usecase_test.dart` 1 failed -> KILLED; reverted ->
    30 passed, 0 failed.
- root regression: `dart analyze` -> "No issues found!" (example/ excluded
  from the root pass per the mcp_demo/zikzak_demo standalone-package
  precedent) and the chunked fast-suite protocol (60 real chunk dirs) ->
  **2385 passed, 0 failed** — byte-identical counts to the pre-feature
  baseline. The 5 tag-selector-empty chunk dirs
  (`test/benchmark`, `test/core/dependencies`, `test/integration`,
  `test/plugins/tdd/scenarios`, `test/property`) show the same pre-existing
  "No tests match the requested tag selectors" quirk as at baseline; zero
  actual test failures introduced or fixed at the root.
- commit: pending (single feature commit per repo convention)
