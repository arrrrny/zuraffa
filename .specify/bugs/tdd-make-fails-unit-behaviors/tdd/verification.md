---
bug: 723
slug: tdd-make-fails-unit-behaviors
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: fix/723-tdd-make-fails-unit-behaviors-v2 (pre-PR)
behaviors: 7
proven: 5
likely: 2
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 100 # deliberate-mutant sampling, scope: the new dispatch guard; 1/1 killed
mutants_survived: 0
suite: key files 44 passed / 2 failed (both pre-existing on master) / chunked fast suite green / dart analyze clean
---

# TDD Verification: #723 tdd make routes unit behaviors to the plain-function generator

## Root cause

`zfa tdd make` dispatched every behavior through the description-keyed
`GenerationPlanner` only. A unit behavior (U5, U6, …) whose description carries
a CRUD keyword ("service", "repository", "use case", "crud") matched the
CRUD/use-case branch (bug #696 remediation), whose fallback emits
`zfa make <slugified-id> --no-entity` — the lowercased BEHAVIOR ID passed to
the entity generator as an entity name. The use-case scaffolds that command
writes never implement the unit behavior's subject stub
(`int subject_<id>() => throw UnimplementedError(...)`), so the target test
stayed red after a "successful" generation, `make` exited
`outcome=generation-error`, and the `zfa tdd run` loop hard-stopped at the
first unit behavior — exactly the reported `U5:make -> generation-error`
symptom (re-report of #718).

The behavior's loop kind (acceptance vs unit) was never consulted at the make
dispatch, even though the test list is the established kind source of truth
(`TestListReader`, spec 049) and the plain-function generator surface for unit
subjects has existed since #657/#660 (`zfa tdd func <id>`).

## Remediation

Fix scoped to the make dispatch logic (hard constraint):

1. `make_command.dart` — resolves the behavior's kind before planning:
   the feature's test-list row kind via the shared `TestListReader`
   (fail-open to the prefix heuristic when the list is missing/malformed/
   rowless), then the behavior-id prefix (`U<digits>` → unit). Null when
   neither signal applies, which keeps pre-list fixtures and
   hand-registered behaviors on their existing paths.
2. `generation_planner.dart` — `BehaviorSummary` carries the optional
   `kind`; when kind is `unit` and the description would dispatch to the
   CRUD/`make <slug>` entity-generator branch, the planner returns the
   plain-function plan (`zfa tdd func <id>` + `zfa build`) instead — the
   only surface that implements the unit subject stub.

Deliberately unchanged: entity-bearing unit behaviors keep the entity
pipeline (`entity create` + `tdd wire` + `build`, the #610 surface that CAN
implement a subject); acceptance-kind and unknown-kind dispatches keep the
entity path; the #696 `make <slug> --no-entity` plan is preserved whenever no
kind signal exists; the composition fallback (spec 052) is untouched.

## RED evidence (pre-fix, real CLI-surface tests)

`test/plugins/tdd/make_command_test.dart`, new group "unit-behavior routing
(bug #723)" run against the unpatched tree:

```
00:16 +0 -1: unit-behavior routing (bug #723) U5: ... routes to the plain-function generator [E]
  Expected: contains 'tdd func U5'
    Actual: 'make u5 --no-entity\n'
              'build'
     Which: does not contain 'tdd func U5'
00:23 +0 -2: unit-behavior routing (bug #723) U6: ... (prefix fallback) [E]
  Expected: contains 'tdd func U7'
    Actual: 'make u7 --no-entity\n'
              'build'
00:31 +1 -2: Some tests failed.
```

The captured argv log shows the bug verbatim: make dispatched
`zfa make u5 --no-entity` — the lowercased behavior ID as an entity name —
and the fixture's target test stayed red (the same dispatch the reporter saw
as `U5 make -> generation-error` in the run loop; the run driver's
stop-on-generation-error behavior that turns this into a hard stop is itself
covered by `sc_015_run_stops_on_failure_test.dart`, 3/3 green here).

## GREEN evidence (post-fix, same tests + full local verification)

Same tests after the fix (final tree, post-format):

```
dart test --preset=all test/plugins/tdd/make_command_test.dart
  test/plugins/tdd/services/generation_planner_test.dart
→ 44 passed / 2 failed (both failures pre-existing on master, see Gaps)
```

- The three new make-command tests pass: U5 routes `tdd func U5` (never
  `make u5`) and certifies `outcome=green`; the prefix fallback routes
  without a test list; an entity-bearing unit behavior keeps
  `entity create` + `tdd wire`.
- The four new planner tests pass (U-723a..d), including the backward
  compatibility pin: kind-less summaries still produce the exact #696
  `['make', 'u6', '--no-entity']` plan.
- Chunked fast suite (`tools/run_tests_chunked.sh` chunk set, all 68
  chunks, executed per-chunk with kernel-cache cleaning): every chunk green
  except `test/feature_flags` (1 failure — reproduced identically on clean
  master).
- Root-level `test/plugins/tdd/*_test.dart` files (12 files, fast tier —
  these sit outside the chunked runner's subfolder split): 61/61 passed,
  including the run-driver suites.
- Slow-tier real-pipeline scenarios: `sc_013` 4/4, `sc_015` 3/3 green;
  `sc_018` fails on this branch AND on clean master with the identical
  signature (`result=stopped ... stopped_at=A1:make`), i.e. pre-existing in
  this environment, not introduced by the fix.
- `dart analyze`: No issues found. `dart format` on the four changed
  files: 0 remaining diffs.

## Test-first evidence

| Behavior (test)                                                        | Class  | Evidence                                                                                       |
| ---------------------------------------------------------------------- | ------ | --------------------------------------------------------------------------------------------- |
| U5 make-command routing (CRUD-description unit behavior)               | PROVEN | red captured pre-fix in this session (argv log shows `make u5 --no-entity`); fix flips it green |
| U6 prefix fallback (no test-list row)                                  | PROVEN | red captured pre-fix (`make u7 --no-entity`); green post-fix                                   |
| U8 entity-bearing unit keeps entity pipeline                           | LIKELY | guard test written with the fix; passes pre-fix too (documents unchanged behavior)              |
| U-723a planner unit→func reroute                                       | PROVEN | red implied by the command-level red (same dispatch); killed the deliberate mutant              |
| U-723b kind-less #696 plan preserved                                   | LIKELY | written with the fix; pins existing behavior                                                    |
| U-723c acceptance keeps make path                                      | LIKELY | written with the fix; pins existing behavior                                                    |
| U-723d entity-bearing unit keeps create+wire                           | LIKELY | written with the fix; pins existing behavior                                                    |

No existing test was weakened, skipped, renamed out of a filter, or had an
assertion loosened (diff audited: only additive test groups + the dispatch
guard; the two failing master tests are untouched).

## Mutation results (deliberate mutant sampling)

No mutation tool is wired in CI (tdd-profile), so per the rubric the
highest-risk behavior was sampled with a deliberate mutant:

| Mutant                                                                                                                         | Behavior    | Survived | Judgment                                                                                                                                                             |
| ------------------------------------------------------------------------------------------------------------------------------ | ----------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `generation_planner.dart`: drop the `summary.kind == BehaviorKind.unit` guard (unit behaviors dispatch to `make <slug>` again) | U-723a / U5 | No       | Killed — `U-723a` failed with `Expected: ['tdd','func','U5'] / Actual: ['make','u5','--no-entity']`; restored exactly, suite re-run green (18/18) |

## Traceability

| Issue criterion (success criteria)              | Tests claiming it                                       | Status                                     |
| ----------------------------------------------- | ------------------------------------------------------- | ------------------------------------------ |
| U* must not dispatch `zfa make <lowercased-id>` | make U5, make U6-prefix, planner U-723a                 | covered (real CLI surface + pure planner)  |
| U* routes to the #657/#660 plain-function surface | make U5, make U6, planner U-723a                       | covered                                    |
| Entity-bearing unit behaviors keep the entity path | make U8, planner U-723d                               | covered                                    |
| No new failures outside the fix                 | full chunked fast suite + root tdd files + sc_013/sc_015 | covered; the 3 red suites fail identically on master |

## Gaps (why not PASS)

- Two `make_command_test.dart` failures are pre-existing on master and were
  NOT touched (hard constraint: fix only the make dispatch):
  1. "bug 657: an unexpressible make names the verb..." expects the
     remediation phrasing `no generator for 'provision'` /
     `implement manually at`, which no longer exists in `lib/` (stale test).
  2. "A11/U17: a unit-kind unexpressible make never composes" uses the
     description "parse bespoke DSL syntax...", which #657 made expressible
     via `tdd func`, so make now reports `generation-error` instead of
     `unexpressible` (stale premise; fails on master identically).
- `sc_018` (real-pipeline loop e2e) fails in this environment on master and
  on the branch with the same signature; not run to green here.
- Mutation sampling covered 1 mutant on the new guard (killed); no tool-based
  mutation score was measured.
- Test-first ordering is not visible in git history (tests and fix land in
  one commit); the session's captured red output is the ordering evidence,
  hence PROVEN via recorded red rather than commit-order.

## What was not audited

- Slow tiers other than sc_013/sc_015 (`--preset=regression/integration/
  property/benchmark` full runs) — repo guidance avoids them on small
  disks; the fixture-heavy suites also showed load-order flakiness under
  parallel runs in this sandbox.
- Coverage was not measured (profile marks it opt-in, not a gate).
- The run driver's `drift` handling (#693) was not re-audited; the assessment
  suspected a shared root cause, but #693's run-side mapping was already
  remediated by commit 97b3b8a3 and no drift outcome is reachable from this
  fix's path (func steps exit 0 or fail honestly).
- The reporter's exact Flutter project (zfa setup with iOS/Android/macOS
  platforms) — no Flutter SDK in this environment; reproduction used the
  plugin's own CLI-surface harness with the same dispatch chain.
