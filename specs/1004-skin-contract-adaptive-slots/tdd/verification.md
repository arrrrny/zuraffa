# TDD Verification — spec `1004-skin-contract-adaptive-slots`

RED → GREEN → verify, with REAL evidence from this branch's runs.
Every count and exit code below comes from an actual invocation in
this session (Dart SDK 3.13.3 (stable) on linux-x64; base commit
`f9f9bc5a` = master "Merge pull request #1175"); nothing is inferred.

## 1. Root cause (TDD step 1)

Read before implementing: `zfa tdd plan`
(`lib/src/plugins/tdd/commands/plan_command.dart`),
`renderSkinPlan` (`lib/src/plugins/tdd/services/lane_split.dart`),
`TestListReader` (`lib/src/plugins/tdd/services/test_list_reader.dart`),
the #1000 lanes spec
(`specs/1000-spec-template-core-skin-lanes/spec.md`), the #1164
skin-contract emitter
(`lib/src/plugins/tdd/services/skin_contract_emit.dart`), and the
issue body (#1004).

- `zfa tdd plan` had NO skin contract: the `## Lanes` adaptive_slots
  rendered as a bare slot list (#1000) and nothing else — no platform
  matrix, no state machine, no route table, no machine JSON.
- No `## Skin Contract` grammar existed in the spec template or in any
  parser; the 004-login-ui spec carried a PROSE token/value table
  (nothing machine-parseable).
- The widget lane therefore invented finders from scenario literals
  (#964) — the exact failure the issue names.

## 2. RED (step 2 — reproduced before any implementation)

The tests were written FIRST and failed on the pristine clone
(master @ `f9f9bc5a`, before any of this spec's code landed).

Reproduce run (the #1004 fixture spec seeded to a temp project, plan
succeeded and the emitted `04-SKIN.md` was inspected):

```text
$ dart run bin/zfa.dart tdd plan --project <tmp> 004-login-ui
zfa tdd plan: wrote …/tdd/04-ENGINE.md (3 CORE behaviors), …/tdd/04-SKIN.md (1 SKIN behaviors), …/tdd/04-CONTRACT.md; test-list.md is the lane meta-index (5 behaviors, 1 BOTH).
exit 0

$ grep -c "Platform contract\|State machine contract\|Route contract\|Skin contract (machine)" …/tdd/04-SKIN.md
0          ← the Skin Contract section is completely ignored
```

The test files, run against the unimplemented feature:

```text
$ dart test test/plugins/tdd/commands/plan_skin_contract_1004_test.dart
00:00 +1 -10: Some tests failed.
Failing tests (all honest assertion failures — 04-SKIN.md carries no
contract sections, the refusals do not fire, the real 004-login-ui
spec and the template carry no grammar):
  04-SKIN.md carries the platform, state-machine, and route contract sections
  platform rows: every adaptive slot with its overrides, tied to the skin behaviors
  state-machine rows: initial -> loading -> data with error/empty alternates
  route rows: navigation target, screen class, route path
  the machine contract is JSON-parseable and schema-validated
  a Skin Contract with no ## Lanes section refuses (the contract rides the SKIN lane)
  an unknown contract key refuses naming the key
  adaptive_slots disagreeing with the SKIN lane refuses naming the drift
  the spec for 004-login-ui contains the explicit Skin Contract section and plans green
  the spec template documents the Skin Contract grammar
  (+1 passing: TestListReader still resolves every behavior row — the
   pre-existing reader behavior, the regression guard baseline)

$ dart test test/plugins/skin_contract/adaptive_skin_contract_test.dart
Failed to load — compile red:
  Error when reading 'lib/src/skin/contract/adaptive_skin_contract.dart': No such file or directory
  Error when reading 'lib/src/skin/contract/adaptive_skin_contract_parser.dart': No such file or directory
  Error when reading 'lib/src/skin/contract/adaptive_skin_contract_schema.dart': No such file or directory
```

RED captured: `+1 -10` (CLI behavior, assertion-level) + module
compile red. Full transcripts: `tdd/red-evidence.txt`.

## 3. GREEN (step 3 — implementation + passing runs)

Implementation:

- `lib/src/skin/contract/adaptive_skin_contract.dart` — the typed
  model (AdaptiveSkinContract, AdaptiveRouteContract): field spec
  tables, the name pattern, the happy-path/alternate state split,
  the route derivation (`deal_list` -> `DealListScreen`, `/deal_list`),
  `toJson` (the machine contract), value-based equality/hashCode.
- `lib/src/skin/contract/adaptive_skin_contract_parser.dart` — the
  strict declaration parser (fenced yaml, bare body, or a standalone
  `Skin Contract:` key block; the #1164 json fence returns null).
  Unknown/duplicate/missing keys, overrides for undeclared platforms,
  and malformed values throw naming the key.
- `lib/src/skin/contract/adaptive_skin_contract_schema.dart` — the
  JSON Schema generator (draft 2020-12, closed, generated from the
  model's field tables; `$ref` pointer asserted against the `$defs`
  key in tests).
- `lib/src/plugins/tdd/services/lane_split.dart` — `renderSkinPlan`
  renders the four contract sections; no declaration renders the
  pre-1004 shape byte-for-byte.
- `lib/src/plugins/tdd/commands/plan_command.dart` —
  `_resolveSkinContract`: the parse + the refusals (exit 2, no
  artifacts, `--> fix:` lines, verdict.v1 exit classes), and the
  contract passed to `renderSkinPlan`.
- `lib/src/plugins/tdd/services/test_list_reader.dart` — the four new
  section headers join the declarative skip list (declarations, not
  behaviors — the #1000 pattern).
- `lib/src/plugins/tdd/services/skin_contract_emit.dart` — the #1164
  JSON emitter no-ops for the yaml form (coexistence; the json fence
  path and the loud no-body failure are unchanged).
- `.specify/templates/spec-template.md` — the `## Skin Contract`
  grammar with the worked example.
- `example/specs/004-login-ui/spec.md` — the explicit typed section
  (the prose table replaced); the Lanes now declare A1/A2 so the
  real spec plans green.

Actual passing runs (this branch):

```text
$ dart test test/plugins/skin_contract/adaptive_skin_contract_test.dart
00:00 +30: All tests passed!

$ dart test test/plugins/tdd/commands/plan_skin_contract_1004_test.dart
00:00 +11: All tests passed!

$ dart test test/plugins/tdd/plan_skin_contract_test.dart   (the #1164 emitter — semantics unchanged)
00:00 +5: All tests passed!

$ dart test test/plugins/tdd/commands/plan_lanes_1000_test.dart  (the #1000 lanes — hard constraint)
00:00 +11: All tests passed!
```

Dogfood — this spec's own plan emits the contract (the emitted
`tdd/04-SKIN.md` in THIS directory was produced by the run below, not
hand-written):

```text
$ dart run bin/zfa.dart tdd plan 1004-skin-contract-adaptive-slots
zfa tdd plan: wrote …/specs/1004-skin-contract-adaptive-slots/tdd/04-ENGINE.md (6 CORE behaviors), …/tdd/04-SKIN.md (0 SKIN behaviors), …/tdd/04-CONTRACT.md; test-list.md is the lane meta-index (6 behaviors, 0 BOTH).
exit 0
```

`04-SKIN.md` carries the four sections: the platform matrix (4 rows,
`home_indicator_safe_area: required` on ios, `title_bar_alignment:
trailing` on macos), the state machine (`initial -> loading -> data`,
`error`/`empty` alternates), the route table (`login | LoginScreen |
/login`, …), and the fenced machine JSON.

## 4. The REAL acceptance (issue #1004 exit criteria)

### 4a. The spec for 004-login-ui contains an explicit Skin Contract section

`example/specs/004-login-ui/spec.md` declares the section with the
full grammar (`adaptive_slots: [mobile, ios, android, macos]`, the
ios/macos `platform_overrides`, `states: [initial, loading, data,
error, empty]`, `routes: [login, deal_list, settings]`). Proved by
`plan_skin_contract_1004_test.dart` ("the spec for 004-login-ui
contains the explicit Skin Contract section and plans green"), which
seeds the REAL file into a temp project and runs plan against it.

### 4b. `zfa tdd plan 004-login-ui` produces 04-SKIN.md with platform rows, state-machine rows, and route rows

Proved by the same test: plan on the real spec file exits 0 and
`04-SKIN.md` contains `## Platform contract`, `## State machine
contract`, `## Route contract`, and the machine block. The row-level
assertions check the platform rows (per-platform, with the ios/macos
override statements and the W1 behavior tie), the state rows
(`initial -> loading`, `loading -> data`, `data` terminal, `error`/
`empty` alternates), and the route rows (`| login | LoginScreen |
/login |`, `| deal_list | DealListScreen | /deal_list |`, `| settings
| SettingsScreen | /settings |`).

### 4c. The contract is JSON-parseable (schema-validated in a test)

`the machine contract is JSON-parseable and schema-validated` extracts
the fenced block from the emitted `04-SKIN.md`, `jsonDecode`s it, and
validates it against a draft-2020-12 JSON Schema (required keys, closed
properties, name patterns, the route `$defs` ref) — zero violations —
then checks the decoded values mirror the spec declaration. The typed
model's own schema is additionally generated-from-model-tested in
`adaptive_skin_contract_test.dart` (no drift, no orphans, `$ref`
pointer resolves).

## 5. Full-suite verification (this branch)

```text
$ dart analyze
136 issues found.        ← identical count to the pristine base (all
                            pre-existing in examples/todo_tdd/); the
                            new/changed files of this spec analyze clean
                            (lib/src/skin/contract/ + both test files:
                            "No issues found!")

$ tools/run_tests_chunked.sh semantics (one folder at a time, kernel
  caches cleared between chunks, flutter-tagged excluded — the
  cloud-agent-sanctioned runner):
89/89 chunks green; aggregate last-run summaries: 3,478 tests passed,
0 failed. One load-induced 60s timeout flake in
test/plugins/tdd/corpus_economics (batch tests spawning the CLI
in-process — the suites dart_test.yaml itself flags as
ceiling-brushers) re-passed isolated (`+53: All tests passed!`) and
on the chunk rerun; unrelated to this diff (plan/rendering/reader
only). Single-invocation whole-tree runs are NOT used here — the
~6.5GB kernel overflow is the documented small-disk failure mode the
chunked runner exists to avoid.

$ dart format .
Formatted 2337 files (5 changed in the first pass; after the second
pass only examples/mcp_demo/lib/src/mcp/tools.dart would change —
pre-existing drift at the base commit, reverted to keep this PR
scoped). Every file this spec touches is format-clean.
```

## 6. TDD discipline audit (the verify rubric)

- **Test-first**: the two test files were written before the modules
  existed — the RED run above shows the compile failure of the
  not-yet-written modules and the assertion failures of the
  not-yet-wired emission. The implementation then made them pass;
  no test was weakened between RED and GREEN (the only edits: a
  `runCapturing`-returns-String API fix, scoping the platform-row
  lookup to the Platform contract section so the Adaptive-view-slots
  table cannot shadow it, and the lint/format polish).
- **Red-phase evidence**: `tdd/red-evidence.txt` (real transcripts).
- **Mutation audit**: NOT run — `zfa ttd verify`'s mutation_test path
  spawns temp projects with `dart pub get` + `build_runner`; the
  repo's own guidance (dart_test.yaml header, run_tests_chunked.sh
  header) forbids it on small/disposable agents (this box: 9.9GB
  disk). Compensation: the refusal paths (unknown key, no lanes,
  slot drift) are asserted negatively; the parser's error surface is
  asserted per-key; the schema/model no-drift checks are asserted;
  the $ref pointer is asserted; and the 3,478-test fast suite pins
  the touched neighborhoods (plan/lanes/reader/#1164-emitter).
- **Acceptance-criteria coverage**: all 3 exit criteria of the issue
  map to passing tests (4a/4b/4c above); the spec's own SC-001..SC-004
  map to the same tests plus the template assertions.
- **Existing skin test semantics**: unchanged —
  `plan_skin_contract_test.dart` (#1164 emitter) passes byte-for-byte
  its original assertions; `plan_lanes_1000_test.dart` (#1000) passes;
  `schema_test.dart` (the repo-wide colon-heading walker) passes with
  the new specs/ entries present.

## 7. Verdict

**PASS** — the issue's exit criteria are PROVED by real runs: the
004-login-ui spec declares the contract, `zfa tdd plan 004-login-ui`
emits 04-SKIN.md with the platform rows, state-machine rows, and
route rows, the contract is JSON-parseable and schema-validated in a
test, the fast suite is green (89/89 chunks, 3,478 passed / 0
failed), and the pre-existing skin test semantics are preserved.
