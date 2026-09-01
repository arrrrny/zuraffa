---
feature: tdd-make-fails-unit-behaviors-2 (bugfix #723, branch mode)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 264b4dea
behaviors: 6
proven: 6
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 5
criteria_covered: 5
mutation_score: 100 # scope: the changed dispatch decision surface (branch presence, polarity, id-prefix mapping), 3 deliberate mutants — no mutation tool in profile
mutants_survived: 0
suite: fast tier chunked 2531 passed / 0 failed (62 non-empty chunks, 6 slow-only skips); make_command_test slow tier 25 passed / 2 failed (both pre-existing on pristine 47d374c0, stash-proven); GenerationPlanner 18/18; dart analyze clean; dart format clean on all touched files
---

# TDD Verification: #723 `zfa tdd make` routes unit behaviors (U*) to the plain-function generator (v2)

**Verdict: PASS_WITH_GAPS.** The reported failure is reproduced exactly by a
command-level test whose RED was recorded against the pre-fix source (the run
stops at `U5:make` with `outcome=generation-error` after a 2-step plan — the
issue's verbatim shape), the fix makes the generator dispatch kind-based in the
one place dispatch lives, and all three deliberate mutants were caught. Gaps:
the branch is a single commit, so git history alone cannot corroborate
test-first ordering (the recorded pre-fix runs are the evidence); mutation was
deliberate-mutant sampling, not a tool; and this audit was produced by the same
session that wrote the fix and the tests (not independent).

## Root cause (from issue #723 / assessment, confirmed in source)

`lib/src/plugins/tdd/commands/make_command.dart` built the planner's
`BehaviorSummary` from the registry record's description text only (the third
`::` segment of `runnable_test_name`), and
`lib/src/plugins/tdd/services/generation_planner.dart` — the sole
behavior→pipeline translation layer — dispatched ENTIRELY on description
keywords: entity prose → `zfa entity create` + `zfa tdd wire` + `build`;
crud/use-case/repository/service prose → `zfa make <name>` + `build`, where
`<name>` falls back to the SLUGIFIED BEHAVIOR ID (`U5` → `u5`, with
`--no-entity`) when the description names no entity. A unit behavior (U*)
whose description carries that vocabulary — e.g. "use case returns the count
of pending items" — was therefore handed to the entity/make generator with the
behavior id as an entity name. The generated scaffolds never implement the
unit behavior's subject stub (the artifact gen paired with the test), the
target test stays red after generation, make reports
`outcome=generation-error`, and `zfa tdd run` stops at the first unit
behavior. Existing test `U-696b` (generation_planner_test.dart) literally
pinned this wrong routing (`['make','u6','--no-entity']` for "service exposes
the count of pending items") — the dispatch side of the same surface #657/#660
fixed the generator side on.

## The fix

- `GenerationPlanner.plan()` gained a kind-based dispatch branch 0: when the
  summary carries `kind: unit`, the plan is `zfa tdd func <id>` + `build` —
  the #657/#660 plain-function surface — BEFORE any description keyword scan.
  The description-keyed function-verb branch now shares the same `_functionPlan`
  constructor. `BehaviorSummary` gained a nullable `kind`; null keeps the
  pre-#723 description-keyed dispatch, so the #696 contract for kindless
  summaries is unchanged (pinned by new test U-723d).
- `MakeCommand` resolves the behavior's loop kind: the feature's test-list row
  (the shared `TestListReader` contract — the same kind source of truth the
  composition fallback uses), falling back to the repo's id convention
  (`A<n>` acceptance / `U<n>` unit — the SpecParser id scheme `zfa tdd plan`
  reconciles by) when the row or list is absent, and to null for ids outside
  the scheme. The resolution fails soft on a malformed list (the kind is the
  planner's hint, not a make precondition).
- No other file's logic was changed: the run driver's make-outcome contract
  (`green`/`skipped`) is untouched, acceptance surfaces (entity / make /
  composition fallback) are untouched, and `PipelineRunner` already executes
  any plan argv.

## Test-first evidence

| Behavior                                                                                                                            | Class  | Evidence                                                                                                                                                                                                                                                                                     |
| ----------------------------------------------------------------------------------------------------------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| U-723a: unit behavior with CRUD/use-case prose routes to `tdd func <id>`, never `make <slugified-id>`                               | PROVEN | New planner test recorded RED against pre-fix source: expected `['tdd','func','U5']`, actual `['make','u5','--no-entity']` — the issue's exact misfire; the fix turns it green                                                                                                                |
| U-723b: loop kind decides the generator even for entity-bearing unit descriptions                                                    | PROVEN | New planner test recorded RED against pre-fix source: expected `['tdd','func','U2']`, actual `['entity','create','-n','User']`; green post-fix                                                                                                                                                |
| U-723c: acceptance-kind keeps the description-keyed dispatch (entity / make surfaces)                                                | PROVEN | Guard test, green pre-fix and post-fix (a contract that must not regress); MUTANT-2 (condition inverted) caught by it                                                                                                                                                                          |
| U-723d: kindless summary keeps the pre-#723 dispatch (the #696 contract)                                                             | PROVEN | Guard test, green pre-fix and post-fix; pins the null-kind backward-compat path                                                                                                                                                                                                                |
| U-723e: certified-red `U5` (service/use-case prose, no test list → id-prefix fallback) makes green via the func surface               | PROVEN | New command test recorded RED against pre-fix source with the issue's verbatim failure shape: `plan: 2 step(s)` → `target test still fails after generation (exit 1)` → `make: behavior=U5 outcome=generation-error`; post-fix: `outcome=green`, exit 0, fake-zfa log shows `tdd func U5` and never `make u5`, green evidence records the func step |
| U-723f: test-list row is the kind source of truth (inner-loop row routes to func even when only the row kind could tell)              | PROVEN | New command test recorded RED pre-fix (same generation-error shape); post-fix green via `tdd func U5` with the row present                                                                                                                                                                     |

Existing-test changes: none. No assertion was removed, loosened, weakened,
renamed out of a filter's reach, or skipped anywhere in the diff. Pre-existing
tests U-3…U-7, U-8…U-12-657 and U-696a/b/c all pass unchanged — the #696 and
#657 contracts are preserved bit-for-bit.

## Findings

| # | Severity | Finding                                                                                                                                                                                                 | Evidence                                                        |
| - | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------- |
| 1 | MED      | Redundant test: U-723d pins the same plan (`['make','u6','--no-entity']` for the same kindless summary) that U-696b already pins — one bug would fail both. Kept deliberately as the explicit contract pin for the NEW null-kind semantics introduced by this fix, but the two should be merged or re-worded to reference each other in a follow-up | `test/plugins/tdd/services/generation_planner_test.dart` (U-723d vs U-696b) |
| 2 | LOW      | The kind resolution's prefix fallback `^([AU])\d+$` accepts only the SpecParser id scheme; exotic ids (e.g. `U-100`, `B-200`) resolve kindless and keep description-keyed dispatch. Correct today, but worth a line in the planner doc comment if the scheme ever widens | `lib/src/plugins/tdd/commands/make_command.dart` `_kindFromId`  |
| 3 | INFO     | Pre-existing master failures, unrelated to this fix, verified identical on pristine `47d374c0` by stash-run: `make_command_test.dart` "bug 657: an unexpressible make names the verb…" and "A11/U17: a unit-kind unexpressible make never composes" — both stale #657-era fixtures whose descriptions contain verbs ('parse', 'convert') that #657 made expressible; they fail identically pre- and post-fix (master 23 passed / 2 failed vs fix 25 passed / 2 failed) | this audit's baseline runs                                      |
| 4 | INFO     | `dart format .` on the tree reformats one unrelated file (`examples/mcp_demo/lib/src/mcp/tools.dart`) — pre-existing drift vs the Dart 3.13.3 formatter, left untouched (minimal-fix constraint); the PR's 4 touched files are format-clean | `dart format --set-exit-if-changed lib/src/plugins/tdd test/plugins/tdd` → 0 changed |

No `HIGH` smells in the new tests: they assert concrete argv sequences,
summary lines, exit codes, and cycle-log evidence through the real entry point
(`CliRunner` → `MakeCommand` → `GenerationPlanner` → real subprocess spawns of
the scripted fake zfa), use the suite's recorded helpers (`TddFixture`,
`writeFakeZfaBin`, `readFakeZfaLog`, `seedCertifiedRed`, `seedTestList`),
contain no conditional logic, are deterministic (throwaway temp fixtures, no
clocks/network/sleep), and their failure output names the broken behavior.
Planner tests follow the file's existing bug-657/bug-696 group style; command
tests follow the neighboring spec-052 group style.

## Mutation results (deliberate mutants — no mutation tool in profile)

| Mutant                                                                                     | Behavior      | Survived | Judgment                                                                                                                              |
| ------------------------------------------------------------------------------------------ | ------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| MUTANT-1: kind branch disabled (`if (false && summary.kind == BehaviorKind.unit)`) — restores the pre-fix description-keyed dispatch | U-723a        | No       | Caught: plan reverts to `['make','u5','--no-entity']`; restored exactly, planner suite 18/18 green                                       |
| MUTANT-2: condition inverted (`kind != BehaviorKind.unit`) — acceptance behaviors routed to the func surface                         | U-723c        | No       | Caught: acceptance `make`/`entity` expectations fail (`Expected: 'make' Actual: 'tdd'`); restored exactly, planner suite 18/18 green      |
| MUTANT-3: id-prefix mapping flipped (A↔U in `_kindFromId`) — unit-prefix behaviors resolve acceptance and fall back to description dispatch | U-723e        | No       | Caught: command run reverts to the `make u5` route and `outcome=generation-error`; restored exactly, both U-723 command tests green       |

Sample: 3 of 3 mutants over the changed logic's full decision surface (branch
presence, polarity, prefix mapping) — exhaustive for this dispatch; the rest of
`generation_planner.dart` (entity/CRUD name derivation) and `make_command.dart`
(resolution, guard, evidence) were not mutated.

## Traceability (issue #723 criteria → tests)

| Issue criterion                                                                                       | Test / evidence                                                                                                          | Real entry point?                                             |
| ------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| Unit behaviors (U*) route to the plain-function generator (#657/#660 surface), not the entity generator | U-723a (planner argv), U-723e (command run, func route in pipeline log, `outcome=green`)                                     | yes — `CliRunner` → `MakeCommand` → planner → real subprocess spawns |
| Dispatch is based on the behavior's prefix/kind, not the lowercased id                                  | U-723b (kind over description), U-723f (test-list row kind), U-723e (id-prefix fallback)                                     | yes (U-723e/f end-to-end; U-723b at the dispatch unit)           |
| Run loop reaches a U* behavior and make proceeds (drift or green), run continues                        | U-723e/f prove make exits 0 with `outcome=green` for a unit behavior — exactly the summary contract `StepRunner` consumes (`green`/`skipped` → success, run advances); the driver's spawn path is unchanged by this diff and covered by `run_command_test.dart` (green in the fast tier) | yes, at the make/driver contract boundary                        |
| Full suite: NO NEW failures                                                                             | chunked fast tier 0 failed (2531 tests); every slow-tier failure re-verified as pre-existing on pristine `47d374c0`          | yes — the repo's own chunked runner and presets                  |
| Fix ONLY the make dispatch logic (scope)                                                                                | diff = 2 source files (the dispatch owner + the summary builder) + 2 test files; `dart analyze` clean; run driver untouched   | yes — inspected via `git diff --stat 47d374c0..264b4dea`          |

Also closes the #718 shape by construction: the same dispatch site and the same
repro shape (U5) are pinned by U-723a/U-723e.

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- The audit is not independent: the same session wrote the fix and the tests.
  A fresh-context reviewer should treat this report as the author's own grade.
- No mutation tool was used (profile has none); the deliberate-mutant sample
  covers only the changed dispatch decision surface, not the whole planner or
  make command.
- The regression/integration/property/benchmark presets were not run
  (dart_test.yaml advises against them on small cloud agents); the fast tier
  plus the `make_command_test.dart` slow file were run for real.
- The two pre-existing `make_command_test.dart` failures (finding 3) were
  verified as pre-existing, not fixed and not re-diagnosed beyond their #657
  staleness; fixing them is out of this bug's scope per the one-PR constraint.
- Gen's stub-emission contract (044) and func's return-type derivation are
  relied upon as tested by their own suites; they were not re-audited here.
- Performance of the per-make test-list read (one small file read per make
  invocation) was not measured.
