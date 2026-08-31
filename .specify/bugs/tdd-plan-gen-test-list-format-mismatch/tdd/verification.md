---
feature: tdd-plan-gen-test-list-format-mismatch
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 29c2aa38
behaviors: 4
proven: 0
likely: 4
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: n/a # no mutation tool; deliberate mutants 2/2 caught (canonical-shape drift, target-defaulting drop), both restored byte-identical and re-run green
mutants_survived: 0
suite: fast tier chunked 2513 passed / 1 pre-existing failure (cycle_entry green-entry rendering — fails on clean HEAD too); affected-area slow tier 160 passed / 0 failed incl. sc_018 loop e2e (4:41) and sc_017 (2:10); mcp chunk hangs in this sandbox (unrelated — zero import overlap)
---

# TDD Verification: tdd plan↔gen test-list format mismatch (#617)

**Verdict: PASS_WITH_GAPS.** The bug's acceptance — `zfa tdd run` gets PAST
gen on a plan-written list and drives it to all-DONE — is proven end to end
by sc_018: real `zfa tdd plan` writes the canonical 4-column list, real
`zfa tdd run` (real `gen` → `verify-red` → `make` with `entity create` +
`tdd wire` + `build_runner` via a pure exec forwarder) drives 2 behaviors
(A1 + U1) to `result=complete pending=0 red=0 green=0 done=2` in 4:41, with
one red + one green evidence entry per behavior and both subjects wired by
the pipeline. The pre-fix failure signature (`unknown behavior id "A1"`,
`stopped_at=A1:gen`) is asserted absent. Gaps: test-first evidence is
`LIKELY` (the red ran in-session before the fix — 6 failing tests failing
for exactly `unknown behavior id` — but test + fix land in one commit per
repo convention, so git history alone cannot show ordering), and mutation
was the deliberate-mutant procedure (no mutation tool in the profile), 2
mutants sampled on the two highest-risk seams.

## Test-first evidence

| Behavior | Class  | Evidence |
| -------- | ------ | -------- |
| B1 — gen resolves acceptance behaviors from plan's 4-column list (the bug) | LIKELY | `plan_gen_contract_test.dart` "gen resolves an acceptance behavior planned by plan" ran RED first: `zfa tdd gen: unknown behavior id "A1"` (6/6 failing for that exact reason), then GREEN after the reader unification |
| B2 — gen resolves unit behaviors from plan's 4-column list | LIKELY | Same RED batch: `unknown behavior id "U1"` → green; asserts test+subject files and `source_criterion: FR-001` |
| B3 — the shared reader is the single contract (kind from section header; target defaulting moved into the reader; 6-column dialect only via a warned compat shim) | LIKELY | 11 reader tests: canonical 4-column target defaulting (`subject_a1`/`subject_u1`), shim parses legacy 6-column rows (kind from cell, target verbatim/defaulted), invalid-kind 6-column row and unknown-state row still malformed with line numbers, 4-column outside a section still malformed |
| B4 — the full loop plan → run → DONE on a real temp project with the real pipeline | LIKELY | sc_018 (slow, integration): plan exit 0 → run exit 0 `result=complete ... done=2`; `unknown behavior id` / `stopped_at=A1:gen` / `result=stopped` asserted absent; cycle-log red+green for A1 and U1; subjects free of `UnimplementedError` |

No pre-existing test was weakened or loosened — the test diff is additions
only (`git diff` shows zero removed assertion lines). Existing 6-column
fixtures (`gen_command_test.dart`, `sc_017`, `verify_red_command_test.dart`)
run UNCHANGED through the compat shim and pass (9/9, 1/1, 19/19), which is
the shim's purpose: one release of compatibility, with a stderr deprecation
note steering re-runs of `zfa tdd plan`.

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | The deprecation shim is verified for parsing semantics but its stderr warning text is not asserted by any test — the migration nudge could regress silently | `test_list_reader.dart` stderr writeln; no test captures it |
| 2 | MED | CI (`ci.yaml` dart_core) runs `dart test test` — the default FAST tier — so the slow-tier loop e2e (sc_018) that pins the format contract at the loop's front door is not executed by the CI job as written; the repo's documented full gate is `dart test --preset=all` (dart_test.yaml: "CI / pre-commit"). Wiring a preset=all (or integration-preset) job is a CI change outside this bug's scoped files | `.github/workflows/ci.yaml:36`, `dart_test.yaml` presets |
| 3 | LOW | gen's multi-feature scan now stops honestly on a malformed test list in ANY feature dir (TestListReadException propagates) instead of silently skipping — intentional (the silent-skip was the bug's anti-pattern), but a repo with one broken legacy list blocks gen for unrelated features until fixed | `gen_command.dart` `_resolveBehavior` try/catch |
| 4 | LOW | The 6-column shim accepts rows whose kind cell wins over the section header; a hand-written list with contradictory section/kind gets the cell's kind without a mismatch warning | `test_list_reader.dart` `_kindFromCell` |

## Mutation results

No mutation tool in the profile; deliberate mutants on the two highest-risk
seams (the canonical-shape gate and the moved defaulting).

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| canonical 4-column acceptance `cells.length == 5` → `== 6` (shape drift — the bug's anti-pattern reintroduced) | B3 | NO — 11 failures across plan_gen_contract + reader tests | caught immediately by the contract tests |
| `resolveDefaultTarget` returns the raw cell (defaulting dropped) | B1/B3 | NO — 8 failures (target defaults, shim empty-target rows) | caught by both the reader tests and the gen-level target assertions |

Both mutants restored byte-identical (`diff` vs pre-mutant copy: empty) and
the focused suites re-run green (17/17).

## Traceability

| spec.md criterion (bug assessment) | Behaviors | Tests |
| ---------------------------------- | --------- | ----- |
| plan-written list → gen resolves (impossible pre-fix) | B1, B2 | plan_gen_contract_test (2 bug RED tests + 3 support tests); reader tests |
| test-list format is a SINGLE contract; kind from section header; target defaulting in the reader | B3 | test_list_reader_test 11 tests |
| plan's 4-column output stays canonical | B3 | plan_gen_contract "plan writes the canonical 4-column test list" (asserts header shape AND `isNot(contains('kind'))`) |
| ONE slow-tier e2e that is exactly the run-c demo (plan → run, real pipeline) | B4 | sc_018_plan_run_loop_e2e_test.dart |

No criterion without a test; no test tracing to nothing.

## What was not audited

- The full SLOW tier outside the affected area (specs' own scenario suites,
  regression/integration/property/benchmark tiers beyond `test/plugins/tdd`)
  was not run in this session; CI's fast gate does not execute them either.
- `test/plugins/mcp` could not run in this sandbox: `dart test
  test/plugins/mcp` hangs at process spawn (MCP host) with and without this
  change; it imports nothing from the changed files (verified by grep), so
  it is environment-blocked, not failing.
- One pre-existing failure is flagged, not fixed (auditor does not fix):
  `test/plugins/tdd/models/cycle_entry_test.dart` "green entry renders
  omitted evidence as missing" expects `- generation:\n  (evidence
  missing)` but the renderer prints `- generation:\n  (none)` — confirmed
  failing on clean HEAD (29c2aa38) with this branch's changes stashed.
  Unrelated to #617 (cycle-log rendering, not the test-list pipeline).
- Mutation was sampled (2 deliberate mutants), not exhaustive; no coverage
  run (profile's coverage command was not exercised).
- The deprecation warning's stderr output was not captured/asserted
  (finding 1).
