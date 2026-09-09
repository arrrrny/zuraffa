---
feature: 1401-plan-pipe-escape-table-cells
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 80f4ef1
behaviors: 2
proven: 2
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 2
criteria_covered: 2
mutation_score: 1.0 # deliberate mutant (lib fix reverted, tests kept) caught 2/2 assertions red
mutants_survived: 0
suite: bug test 2/2 passed; plan/reader regression surfaces 109/109 passed (15 files incl. sc_018 e2e loop, reader contracts 835/919/833/984/1140/1141, plan 1182/contract-1007/traces-1310/ffi-835, widget-939); dart analyze exit 0 on changed files; dart format clean repo-wide (2501 files, 0 changed)
---

# TDD Verification: plan escapes pipes in table cells; plan and run agree (#1401)

**Verdict: PASS.** The writer-escape / reader-unescape round-trip is
proven end to end in this session against the real CLI loop, with the
deliberate mutant confirming the tests detect the bug rather than
passing vacuously.

## Evidence (all from real runs, this session)

1. **RED (pre-fix, exact issue repro).**
   `dart test test/plugins/tdd/commands/plan_command_pipe_escape_1401_test.dart`
   → `Some tests failed` (2). The failing assertions: writer did NOT
   escape (`Expected: true / Actual: <false>` on the `<all\|active\|completed>`
   on-disk check) and the re-written list was still unescaped. Plan's
   own console reproduced the runner refusal verbatim while reading the
   file the first plan wrote:
   `test-list.md line 26: expected 4 columns (id/behavior/traces/state), found 6: "| U1 | The CLI MUST expose todo filter <all|active|completed> selection on the command line. | FR-001 | PENDING |"`.

2. **GREEN (post-fix).** Same command → `All tests passed!` (+2):
   - plan writes `<all\|active\|completed>` (escaped) on disk;
   - `TestListReader.read()` (the run-leg parser) round-trips the
     ORIGINAL prose `todo filter <all|active|completed>` — the reader
     unescapes, run sees literal pipes;
   - the acceptance row survives the 4-column gate;
   - a second `zfa tdd plan` re-plans through the escaped file with
     ZERO id drift (reconcile keeps A/U numbering; no re-issue).

3. **Deliberate mutant (caught 1/1).** `git checkout HEAD~1 -- lib/…`
   (revert the lib fix, keep the new tests) → `Some tests failed` (2)
   with the same `expected 4 columns, found 6` plan note; restore →
   `All tests passed!` (+2). The suite fails closed without the fix.

4. **Regression scope (only surfaces the changed file feeds).** 15 test
   files / 109 tests, all passed — including the plan→run e2e loop
   (sc_018), every reader contract (835 ffi, 919 entities, 833
   persistence, 984 blank-row, 1140 kind-cell, 1141 contracts), plan
   regression pins (1182 bug-shape resolution, 1007 contract rows,
   1310 traces cells, 835 preserved rows) and the widget-kind gate
   (939). Zero failures, zero pre-existing reds observed.

5. **Static gates.** `dart analyze` on the three touched files:
   `No issues found!`. `dart format` on changed files: applied (test
   file reflowed once); repo-wide `--set-exit-if-changed`:
   `Formatted 2501 files (0 changed)`, exit 0 — no formatting diffs
   remain.

## Success criteria

| Criterion | Status |
| --------- | ------ |
| Writer escapes `|` as `\|` in table cells (all row dialects) | PROVED (A1: on-disk assertion) |
| Reader unescapes `\|` back to literal pipes | PROVED (A1: TestListReader round-trip) |
| Run no longer refuses plan's own output (4-col gate holds for piped prose) | PROVED (A1/U1: reader parse succeeds; refusal note gone) |
| Plan's reconcile agrees with its own writer (re-plan id-stable) | PROVED (U1: zero id drift) |
| No regression on plan/reader surfaces | PROVED (109/109) |
| Fix confined to plan_command.dart + tests (engine/run/verify/grammar untouched) | PROVED (git diff: 1 lib file + 2 test files; 2nd = fixture-path hygiene in behavior_kind_trace_test.dart, commit 17f2271b) |
