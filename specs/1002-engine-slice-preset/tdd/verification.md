# TDD Verification — spec `1002-engine-slice-preset`

RED → GREEN → verify, with REAL evidence from this branch's runs.
Every count below comes from an actual `dart test` invocation; nothing
is inferred.

## 1. Root cause (TDD step 1)

- `zfa make engine <Entity>` did not exist: `MakeCommand` parsed the
  first positional as the entity name, so `engine` became the entity and
  `<Entity>` became an unknown plugin id; there was no `engine` preset
  in `PresetRegistry`, no `zfa engine` verb in `CliRunner`.
- The engine chain could not run in one command anyway: a make run with
  BOTH `mock` and `di` active failed at the generation-transaction
  commit with `Multiple operations for lib/src/di/index.dart` — the
  topological sort kept the request order (usecase, repository,
  datasource, **di**, mock), di wrote `di/index.dart`, and the mock
  plugin's `syncMainIndex()` appended `registerSimulationBindings` to
  the same path through the transactional overlay, producing a second
  operation for the same file.
- No receipt, no per-method mock certification, and `--with=vpc` pulls
  Flutter-importing plugins into the same run.

## 2. RED (step 2 — reproduced before any implementation)

Run on the pristine clone (master @ 77e69f24, branch
`spec/1002-engine-slice-preset` before the changes):

```console
$ dart run bin/zfa.dart -C <tmp-project> make engine Login
❌ Error: Cannot run `zfa make` for "engine": no entity source file was
   found. Create the entity first with `zfa entity create -n engine` …

$ dart run bin/zfa.dart -C <tmp-project> engine check Login
❌ Could not find a command named "engine".
```

And the transaction conflict that blocked the chain (master behavior,
reproduced with a zorphy-deps sandbox):

```console
$ dart run bin/zfa.dart -C <tmp-project> make Login --preset=crud --with=mock --methods=get,getList,create,update,delete
[conflict] Multiple operations for lib/src/di/index.dart
[conflict] lib/src/di/index.dart: File missing
❌ Generation failed: Bad state: Transaction failed:
```

The new tests were written FIRST and failed (RED):

```text
$ dart test test/engine/ test/core/planning/engine_preset_test.dart
00:00 +2 -5: Some tests failed.
Failing tests:
  test/core/planning/engine_preset_test.dart: … registers the engine preset
  test/core/planning/engine_preset_test.dart: … chains the engine-slice generators
  test/engine/engine_checker_test.dart: loading …            (module did not exist)
  test/engine/engine_receipt_writer_test.dart: loading …     (module did not exist)
  test/engine/mock_certifier_test.dart: loading …            (module did not exist)

$ dart test test/commands/make_engine_plan_test.dart
00:00 +2 -3: Some tests failed.     (`make engine` grammar not implemented)
```

## 3. GREEN (step 3 — implementation + passing runs)

Implementation (see `spec.md` "Design"):

- `lib/src/core/planning/preset_registry.dart` — `engine` preset entry.
- `lib/src/commands/make_command.dart` — the `engine` mode token:
  entity auto-create (`EntityCreator`, minimal `id: String`), engine
  defaults (`--methods` → get,getList,create,update,delete), hard
  exclusion of the Flutter-importing plugins, and the post-generation
  engine tail (certifier → checker → receipt).
- `lib/src/commands/engine_command.dart` — the `zfa engine check
  <Entity>` verb (exit 0/1, `--> fix:` on findings, `--format=json`).
- `lib/src/engine/` — `MockCertifier` (per-method certification),
  `EngineChecker` (getIt resolution via the spec-043
  `ServiceLocatorAnalyzer` + lib-wide type index + flutter purity scan),
  `EngineReceiptWriter` (`.zfa/engine.receipt.json`, schema
  `engine.v1`), shared models.
- `lib/src/plugins/di/di_plugin.dart` — `runAfter` gains `'mock'`
  (di runs after mock; `di/index.dart` is written exactly once).
- `lib/src/plugins/mock/mock_plugin.dart` — `syncMainIndex()` skipped
  when di is co-active in the same run (redundant + the transaction
  conflict); standalone `zfa mock create` unchanged.
- `lib/src/plugins/mock/capabilities/create_mock_capability.dart` —
  the `--certify` flag on `zfa mock create`.
- `lib/src/cli/cli_runner.dart` — registers `EngineCommand`.

Actual passing runs (this branch, Dart SDK 3.13.2):

```text
$ dart test test/engine/mock_certifier_test.dart
00:00 +5: All tests passed!
$ dart test test/engine/engine_checker_test.dart
00:00 +8: All tests passed!
$ dart test test/engine/engine_receipt_writer_test.dart
00:00 +3: All tests passed!
$ dart test test/core/planning/engine_preset_test.dart
00:00 +4: All tests passed!
$ dart test test/commands/make_engine_plan_test.dart
00:00 +6: All tests passed!
$ dart test test/commands/engine_check_command_test.dart
00:00 +4: All tests passed!
$ dart test --preset=all test/commands/make_engine_command_test.dart
00:52 +4: All tests passed!
```

34 new tests total (30 fast-tier + 4 slow-tier e2e), all green.

## 4a. Full-suite verification (step 5 — actual runs)

```text
$ tools/run_tests_chunked.sh          # the mandated disk-safe fast-suite runner
OK-equivalent: 75/75 chunks, 0 failures — 71 chunks "All tests passed"
(2922 tests by per-chunk final counts) + 4 SKIPs (slow-tier-only folders:
test/benchmark, test/core/dependencies, test/integration,
test/plugins/tdd/scenarios).
```

Note: `tools/run_tests_chunked.sh` does not cover the 45 root test files
in `test/commands/` (a pre-existing runner gap on master: the folder
exceeds the 40-file split threshold, so `emit_chunks` descends into its
subdirectories and the root files never form a chunk). Those files —
including this spec's 14 new command tests — were run directly:

```text
$ dart test test/commands --concurrency=1
02:00 +145: All tests passed!

$ dart analyze lib/src/            # 9 issues — identical set to master
                                    # (4 pre-existing warnings in
                                    # dependency_mock files + 5 pre-existing
                                    # infos in tdd/gen_command); zero new
                                    # issues from this spec.

$ dart format .                     # 14 files reformatted (the new tests)
$ dart format --set-exit-if-changed --output=none lib test   # exit 0
```

At the default `concurrency: 2`, `dart test test/commands` hits the
pre-existing master flake documented in §6 (dead_positional × doctor
CWD race) — reproduced identically on a pristine master worktree, so it
is not a regression from this branch.

## 4. Refactor (step 4)

None required — the engine module landed as its own layer
(`lib/src/engine/`) and the MakeCommand interception mirrors the
existing value-object plugin-drop pattern.

## 5. Exit-criteria proof (REAL runs, per criterion)

| Criterion | Evidence |
|---|---|
| `zfa make engine Login` produces a runnable engine slice in a single command | e2e test `zfa make engine Login` generates + checks + receipts in one shot: exit 0, entity auto-created, 14+ slice files present (per-method usecases, repository, datasource interface + remote + mock, mock data, usecase/repository DI, simulation binding, `di/index.dart`), no `Transaction failed` |
| `zfa engine check Login` exits 0 | e2e: subprocess `engine check Login` after `make engine Login` → exit 0; the dangling-reference variant deletes `login_remote_datasource.dart` → exit 1 with `LoginRemoteDataSource` + `--> fix:` in stdout |
| The engine slice's test tree contains zero `package:flutter` references | e2e scans every `.dart` under `lib/` and `test/` for `package:flutter` — none; additionally enforced as an `engine check` failure (flutterImport finding with a fix hint) |
| `engine.receipt.json` lists all methods with `mock_certified: true` | e2e parses `.zfa/engine.receipt.json`: schema `engine.v1`, all 5 default methods `{method, mock_certified: true}`, entity sha256 digest, non-empty `di_wired.di_files`, `engine_check.passed: true` |
| Acceptance: `dart analyze` exits 0 in the generated tree | e2e acceptance test: `make engine` → `dart pub get` (zuraffa path dep) → `zfa build --no-analyze` → `dart analyze --no-fatal-warnings lib/src/domain lib/src/data lib/src/di` → exit 0 (zero errors; the only warnings are the pre-existing master-wide `undefined_hidden_name` hide clauses) |
| Hard constraint: non-engine make semantics unchanged | plan tests: `--preset=crud` still resolves `[usecase, repository, datasource, di]`; an entity named `Engine` still routes the classic grammar; `--preset=<other>` + engine token is a usage error (64). `lib/src` analyze count identical to master (9 pre-existing issues) |

## 6. Known pre-existing conditions (not introduced here)

- `test/commands/dead_positional_grammar_test.dart` is flaky under the
  full concurrent `test/commands/` run on MASTER itself (reproduced on
  a pristine master worktree: shared process-global
  `Directory.current` race between the doctor tests' `-C` scopes and
  the probe's `dart run`, issue #441 family). It passes in isolation
  on this branch and on master.
- `make <Entity> --service <Name>` (service-named make runs) generate
  mismatched wiring on master (usecase injects the service while the
  usecase DI passes `getIt<Repository>`; the provider DI never lands).
  The engine preset's default path therefore uses the proven
  repository-mode wiring; the service/provider generators remain part
  of the preset chain and activate when a service is named — their
  output is still checked by `engine check`, which will name any
  dangling reference.
