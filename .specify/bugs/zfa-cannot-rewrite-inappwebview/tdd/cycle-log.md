# Cycle Log: zfa-cannot-rewrite-inappwebview

Append-only evidence for the TDD loop. One entry per cycle.

## Baseline

- commit: fa2c501b
- suite_baseline: `docs_command_consistency` 8/8 green via
  `dart test --preset=regression test/regression/docs_command_consistency_test.dart`
- `dart analyze`: No issues found!
- No doc-scope test existed yet; neither `CLI_GUIDE.md` nor `README.md`
  contained any of the scope-contract strings (`Zuraffa apps`,
  `non-Zuraffa`, `not a malfunction of the CLI`, `file a feature request`).

## Cycle 1 — write failing doc-contract test (RED)

- Test: `test/regression/issue_477_zfa_scope_docs_test.dart`
  (5 tests, tagged `regression, slow` — same pattern as
  `test/regression/docs_command_consistency_test.dart`)
- Command: `dart test --preset=regression test/regression/issue_477_zfa_scope_docs_test.dart`
- Result: FAILED (5 of 5)
- Reason (the RIGHT reason — the scope contract the reporter needed is
  absent from the shipped docs, exactly the expectations gap #477 reports):

```text
00:00 +0 -5: Some tests failed.

Failing tests:
  zfa scope docs (issue #477) CLI_GUIDE.md scopes zfa to Zuraffa apps (#477)
  zfa scope docs (issue #477) CLI_GUIDE.md states zfa does not rewrite non-Zuraffa packages (#477)
  zfa scope docs (issue #477) CLI_GUIDE.md frames zfa doctor output in non-Zuraffa packages as expected (#477)
  zfa scope docs (issue #477) CLI_GUIDE.md routes plugin-rewrite support to a feature request (#477)
  zfa scope docs (issue #477) README.md states the zfa scope for non-Zuraffa packages (#477)
```

  Each failure is a matcher miss of the form
  `Which: does not contain 'Zuraffa apps'` (resp. `does not rewrite existing
  non-Zuraffa`, `not a malfunction of the CLI`, `file a feature request`) —
  no loading/compile errors, no environmental noise.

## Cycle 2 — apply the assessment's remediation (GREEN)

- Change (minimal, no code): a "Scope: what `zfa` operates on" section in
  `CLI_GUIDE.md` (after the intro) and a short "Scope" section in
  `README.md` (between "Why Zuraffa?" and "Installation"). The prose states:
  zfa is a clean-architecture generator for Zuraffa apps
  (zuraffa/zorphy_annotation + `.zfa.json`); it does not rewrite existing
  non-Zuraffa Flutter packages or plugins; `zfa doctor`'s missing-dependency
  output inside such a package is the expected scope check, not a
  malfunction of the CLI; the options are hand-written code, adding the
  Zuraffa deps to opt in, or filing a feature request for non-Zuraffa
  support.
- Command: `dart test --preset=regression test/regression/issue_477_zfa_scope_docs_test.dart`
- Result: All tests passed (5/5), `00:00 +5: All tests passed!`
- Mid-cycle note: the first GREEN run was 4/5 — the phrase
  `not a malfunction of the CLI` was split across a markdown line wrap in
  `CLI_GUIDE.md`; re-wrapping the sentence (same words) made it contiguous
  and the 5th test went green. No assertion was weakened.

## Neighbor contract (unchanged behavior)

- Command: `dart test --preset=regression test/regression/docs_command_consistency_test.dart`
- Result: All tests passed (8/8) — the doc edits did not regress the
  existing doc contract (`zfa make` present, `zfa generate` absent, etc.).

## Suite (fast tier, chunked)

- `dart analyze` → No issues found!
- Chunked fast suite (same per-chunk commands as
  `tools/run_tests_chunked.sh`, driven resumably across the agent's
  tool-invocation timeout; kernel caches cleared between chunks):
  64 chunks — 59 executed tests and **all passed**; 5 chunks
  (`test/benchmark`, `test/core/dependencies`, `test/integration`,
  `test/plugins/tdd/scenarios`, `test/property`) report dart test exit 79
  "No tests ran" because every test in those folders is `slow`/`flutter`
  tagged and the chunk command is `dart test <dir> --exclude-tags flutter`.
  Verified PRE-EXISTING at baseline: with the fix stashed, the same 5
  commands exit 79 identically. Zero real test failures; no new failures.
- `dart format .` → 1 file formatted (the new test file); re-run →
  0 changed. `git diff --stat` shows only the two intentional doc edits.

## Refactor

- None. The fix is additive prose in hand-maintained docs plus one new
  test file; there is no code to restructure and no pipeline-owned output
  touched.
