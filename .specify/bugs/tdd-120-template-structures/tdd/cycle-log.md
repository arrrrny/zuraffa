# Cycle Log: tdd-120-template-structures

Append only. Newest last. Every entry's `red` block is the evidence that the test
existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/` -> 714 passed, 1 skipped, 0 failed (green)
- commit: `79169b56`
- recorded: cycle 0, before any change

## Cycle 1 — RED proof (T002, T004, T006, T008, T010, T012, T014, T016, T018)

- suite: `dart test test/plugins/tdd/bug_919_template_structures_test.dart`
- result: **+4 -10** (4 pass, 10 RED, 0 errors)
- commit: `79169b56`
- added: `test/plugins/tdd/helpers/spec_fixture.dart` (shared `writeSpec` /
  `writeRawSpec` / `makeFeatureDir` + `kMinimalAcceptance` constant).
- expanded: `test/plugins/tdd/bug_919_template_structures_test.dart` from 1 to
  14 behaviors covering A1-A14 (one test per behavior, all driving the real
  `CliRunner.runCapturing(['tdd', 'plan', ...])` on a temp project, same
  harness as `bug_846_coverage_gate_test.dart`).
- RED map (PENDING -> RED):
  - A1 table Key Entities -> `## Key entities` section missing
  - A3 read-back from table -> `## Key entities` section missing (no
    phase-0 path output to read)
  - A4 missing version -> no exit 3, plan proceeds to coverage gate
  - A5 unknown version -> no exit 3, plan proceeds
  - A6 already green (control)
  - A7 Dependencies table -> no `## External dependencies` rendered
  - A8 Layer Contracts -> no `## Layer contracts` rendered
  - A9 undeclared-dependency lint -> no exit 2 (Hive reference uncaught)
  - A10 already green (no-entities case)
  - A11 mixed table + bullet -> bullets ignored after the table
  - A12 already green (no-externals case)
  - A13 missing-version + coverage-gap -> currently throws "no acceptance
    scenarios" (StateError, exit 0) — the gate ordering proof will pass
    when the version gate moves ahead of the parser
  - A14 read-back -> no sections rendered
- next: implement SpecParser table parsing + Template Version gate +
  Dependencies/Layer Contracts extraction + dependency lint, then the
  artifact writer and TestListReader read-back methods, one cycle at a
  time.

## Cycle 1: A1 table-declared Key Entities land in the plan artifact (fields + purpose) — COMMITTED 79ec0bc6

- test: `test/plugins/tdd/bug_919_template_structures_test.dart::A1`
  (suite file pre-existed untracked from an interrupted earlier session,
  aligned 1:1 with the test list; adopted and committed with this cycle)
- red: `dart test test/plugins/tdd/bug_919_template_structures_test.dart --plain-name "A1: table-declared"`
  -> `Expected: contains '| ShoeSizePreference | id: String, sizeEu: double | One saved shoe size for one brand |'` / `Which: does not contain ...` — plan ignores the table form, no entities section rendered (1 failed); suite red map recorded above
- green: `SpecParser.parseKeyEntities` gained zuraffa-1.0 table parsing
  (3-column `| Entity | Fields | Purpose |` header + row regex; `purpose`
  onto `SpecEntity`; table rows/separators tolerated inside the section
  without terminating it) and `PlanCommand._render` emits a third `purpose`
  column when any entity declares one (2-column shape kept for
  purpose-less sections so pre-919 artifacts read back identically).
  Suite: `dart test test/plugins/tdd/` -> 717 passed, 1 skipped, 11 failed
  (8 = this suite's own pending reds A3/A4/A5/A7/A8/A9/A13/A14; 3 =
  verify_red_subdirectory bug #679 child-timeout failures — reproduced on
  a clean tree via stash; `dart bin/zfa.dart` cold JIT startup measured at
  1m36s vs the harness's 75s child cap — environmental, unrelated to this
  cycle; recorded, not attributed, not filtered)
- refactor: none needed — the table path reuses the existing `_fieldPair`
  extraction and identifier validation; bullet parsing untouched
  (FR-002: legacy form byte-identical; the em-dash purpose heuristic of
  the reverted prior implementation was deliberately NOT adopted — the
  issue grants purpose only to the table's third column)
- A11 (mixed table + bullets) was closed by the same patch: its red was
  observed in the suite-level red run (`bullets ignored after the table`);
  the tableMode fall-through to bullet handling is part of A1's minimum
  change, so A11's green is recorded here rather than as a separate cycle.
- commit: `79ec0bc6` (test + implementation; suite file intentionally
  carries the remaining not-yet-green behaviors at this commit — the
  branch's final state is all-green)

## Cycle 2: A3 phase-0 seam read-back — COMMITTED 2561447e

- test: `bug_919_template_structures_test.dart::A3` (had a fixture bug:
  `'$tmpDir/...'` interpolated `Directory.toString()` -> `Directory: '/tmp/...'`,
  so the reader saw no artifact — invalid red, fixed the path construction)
- red: after the fix the test passed on first run — behavior pre-existed in
  the lenient `readEntities`; deliberate mutant (fields read from the
  purpose column `cells[3]` instead of `cells[2]`) -> RED, restored ->
  green. Suite targeted set green.
- refactor: none

## Cycle 3: strict Template Version gate — COMMITTED 8e065358

- tests: `bug_919_template_structures_test.dart::A4, A5, A6, A13`
- red (pre-implementation, suite-level): A4 "no exit 3, plan proceeds to
  coverage gate"; A5 "no exit 3, plan proceeds"; A13 "StateError 'no
  acceptance scenarios', exit 0"
- green: `SpecParser.parseTemplateVersion` + `knownTemplateVersions` +
  plan-side gate before any parsing — missing/unknown marker = exit 3,
  `--> fix:` line, no artifacts. A6 control validated by deliberate
  mutant (gate rejecting `zuraffa-1.0` -> RED), restored.
- fixtures: strict gate broke 21 existing plan tests across
  bug_846/830/833/plan_gen_contract — every planned fixture pins
  `**Template Version**: `zuraffa-1.0`` (T001); all 38 tests green after.
  This is the recorded baseline update the intended behavior change
  required (A2/A10's home tests keep their assertions).
- refactor: none

## Cycle 4: A7 dependencies table — COMMITTED 9f31ca29

- test: `bug_919_template_structures_test.dart::A7`
- red: "no `## External dependencies` rendered"
- green: `SpecDependency` model + `parseDependencies`; artifact section
  `| dependency | type | contract | mock priority |` with declared rows.
- refactor: none

## Cycle 5: A8 layer contracts — COMMITTED 9f31ca29

- test: `bug_919_template_structures_test.dart::A8`
- red: "no `## Layer contracts` rendered"
- green: `LayerContract` model + `parseLayerContracts`; artifact renders
  per-layer `### <layer>` blocks with backticked interface declarations.
- refactor: none (layer grouping extracted into a per-layer map in the
  same render)

## Cycle 6: A14 reader round-trip — COMMITTED d71cd571

- test: `test/plugins/tdd/services/bug_919_reader_test.dart` (new, 3
  tests, written first)
- red: `Error: The method 'readDependencies'/'readLayerContracts' isn't
  defined for the type 'TestListReader'` (unresolved-symbol red)
- green: both methods implemented mirroring `readEntities`' lenient
  section parsing; imports `spec_parser.dart` models; pre-919 artifacts
  yield empty lists. Existing reader suite unchanged/green.
- refactor: none

## Cycle 7: A9/A12 undeclared-dependency lint — COMMITTED 71473db8

- tests: `bug_919_template_structures_test.dart::A9 (exit 2 + fix)`,
  `A12` (no externals / declared only -> exit 0)
- red: A9 "no exit 2 (Hive reference uncaught)"; A12 pre-passed as a
  control — deliberate mutant (lint firing on every statement) -> RED,
  restored
- green: `SpecParser.knownExternalDependencies` (Hive, SharedPreferences,
  Firebase, Supabase, SQLite, Drift) + plan-side scan over requirement
  statements minus the declared set = exit 2 naming each dependency with
  `--> fix:` and no artifacts.
- refactor: none

## Environment deviation (unrelated, recorded)

- `verify_red_subdirectory_test.dart` (3 tests) fails with
  `TimeoutException: zfa subprocess exceeded its 75s child timeout` —
  reproduced on a clean tree via stash; `dart bin/zfa.dart` cold JIT
  startup measures ~1m36s on this machine vs the harness's 75s cap.
  Not caused by this fix; not filtered or weakened; must be re-run
  before merging.
- `subprocess_timeout_test.dart::runTimed ...` failed once under full
  suite load, passes in isolation — transient load flake.

## Correction (append-only record)

- The environment-deviation entry above flagged verify_red_subdirectory
  (bug #679) as failing under the 75s child cap. On the FINAL suite run
  after all cycles closed, `dart test test/plugins/tdd/` -> 731 passed,
  1 skipped, 0 failed — the three tests passed. Environmental (machine
  load/temperature), not code: no mitigation was applied.
