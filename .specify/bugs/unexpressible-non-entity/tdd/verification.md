---
bug: 657-unexpressible-non-entity
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: session 2026-08-31 (branch fix/657-unexpressible-non-entity, pre-commit)
behaviors: 8
proven: 8
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: unmeasured # quick audit — no mutation run on this bug fix
suite: fast 2465 passed, 0 failed (chunked, 60 chunks, exit 0) / targeted slow suites 55 passed, 0 failed (run_command 21, make_command 17, sc_008/009/015 8, sc_013/014 9)
---

# TDD Verification: bug #657 — generator surface for plain functions

**Verdict: PASS_WITH_GAPS.** Every behavior in the fix carries recorded
red-then-green evidence from real CLI-driven runs, all four remediation
criteria from the refined assessment reach a test, and the full fast suite
(2465 tests, chunked, disk-safe runner) plus the targeted slow suites pass
with zero new failures. The gaps that keep this from `PASS`: mutation
strength was not measured (no mutation run — `quick`-class audit on a
disposable cloud agent), and the audit was produced by the same session
that wrote the fix (see "Audit independence disclosure").

## Audit independence disclosure

The same session authored the fix, the tests, and this audit. Mitigations
applied: every red run was executed and its output captured verbatim before
the corresponding fix landed; every green number below comes from a real
`dart test` process in this session, not from memory; the full fast suite
was re-run through `tools/run_tests_chunked.sh` after `dart format .` and
the planner/func suites were re-run again post-format.

## Test-first evidence

The RED phase ran BEFORE any source change: the four failing suites were
executed against the unmodified tree and failed for the RIGHT reason
(below). The GREEN phase then applied the fix and re-ran the same suites.

| Behavior (assessment remediation) | RED evidence (verbatim failure mode) | GREEN evidence |
| --- | --- | --- |
| Planner maps function-intent verbs to `tdd func` | U8-657: `Expected: true / Actual: <false>` with the unexpressible reason naming "render returns a non-empty string..." — generation_planner_test.dart:163; U9-657 same for all six verbs | U8-657/U9-657 pass; U10-657 (entity precedence) and U11-657 (spec 003 U3 stays unexpressible) pass |
| `zfa tdd func` scaffolds a description-derived return type for a no-argument function | All 8 U-F tests fail: `Could not find an option named "--project"` — the `tdd func` subcommand did not exist | U-F1..U-F8 pass (18/18 with planner, re-verified post-format) |
| make's unexpressible message carries the manual-implementation hint | `Expected: contains 'no generator for \'provision\''` against the old bare capability report | hint test passes; render-type behavior's make plans `tdd func` through the pipeline and certifies green |
| Run defers a unit `unexpressible` make instead of hard-stopping | `[run] B-002 make -> unexpressible` then `step failed — behavior=B-002 step=make outcome=unexpressible`, `result=stopped pending=1 red=1 green=0 done=1 stopped_at=B-002:make` — the whole feature blocked | bug-657 deferral test: B-003 runs, refactor defers, honest stop at phase-2 re-attempt (`pending=0 red=1 green=1 done=1`); unexpressible→ok test completes the feature (`result=complete done=3`) |

## Suite evidence (real runs, this session)

- `dart analyze` — No issues found (whole repo, post-fix).
- `tools/run_tests_chunked.sh` (fast suite, disk-safe) — exit 0, 60/60
  chunks green, **2465 passed / 0 failed**.
- Targeted slow suites (real `dart test --preset=all --tags=slow` runs):
  - `test/plugins/tdd/run_command_test.dart` — **21 passed / 0 failed**
    (includes updated U20 contract and the two new bug-657 tests).
  - `test/plugins/tdd/make_command_test.dart` — **17 passed / 0 failed**
    (includes updated US4/A12 descriptions and the two new bug-657 tests).
  - `sc_008_misfire_stop_test.dart` + `sc_009_summary_contract_test.dart` +
    `sc_015_run_stops_on_failure_test.dart` — **8 passed / 0 failed**
    (A7 rewritten to the bug-657 deferral contract).
  - `sc_013_run_drives_feature_test.dart` + `sc_014_run_resumes_test.dart`
    — **9 passed / 0 failed** (bug #625/#635 machinery unchanged).
- `dart format .` then `dart format --set-exit-if-changed --output=none .`
  — exit 0: zero remaining formatting diffs.
- Disk housekeeping: `.dart_tool/test` kernel caches and /tmp fixture dirs
  deleted after each phase; `df -h .` shows 8.0G free (15% used) at
  verification time.

## Criteria coverage (from assessment.md remediation)

1. **Generator surface for plain functions** — `zfa tdd func` (PROVEN:
   U-F1..U-F8 through the real CLI surface via CliRunner).
2. **Planner verb-phrase mapping** — render/format/parse/compute/convert/
   return, with entity/CRUD precedence and the genuinely-unmapped class
   still unexpressible (PROVEN: U8-U11-657 + unchanged U3-U7).
3. **Non-stop fallback in the run** — phase-1 deferral for ANY behavior
   whose make reports unexpressible, refactor deferral while any behavior
   sits RED, phase-2 re-attempt, honest stop only at phase 2 (PROVEN:
   run_command bug-657 tests + updated U20/A7 + unchanged sc_013/sc_014).
4. **Actionable make message** — `no generator for '<verb>'; implement
   manually at <stub_path>, then re-run.` (PROVEN: make hint test pins
   verb, stub path, and resume phrasing; outcome/exit contract unchanged).

## What was not audited

- Mutation strength: no mutation run was executed for this fix (quick-class
  audit; the mutation harness targets specs 041/047 scopes, not bug fixes).
- The real-CLI end-to-end path (`zfa tdd run` against a live `zfa` binary
  spawning the real `tdd func` inside a fresh pub get) is covered at the
  fake-bin level here; sc_017-style real-pipeline proof for `func` would
  need a slow-tier scenario of its own.
