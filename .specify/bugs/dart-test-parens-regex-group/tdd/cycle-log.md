# Cycle Log: bug #760 — dart test -n treats parens in the behavior name as a regex group

Append only. Newest last. Every entry's `red` block is the evidence that
the test existed and failed before the implementation.

## Baseline

- suite: fast tier via `tools/run_tests_chunked.sh` (66 chunks: 61 PASS,
  5 SKIP slow-tier-only) — run AFTER the fix landed in the working tree;
  no pre-fix full-suite baseline was captured in this session. The
  pre-fix state is evidenced by the targeted red below.
- commit: `273e5cd` (fix/760-tdd-parens-regex branch base = master HEAD)
- recorded: cycle 0, before any change

## Cycle 1: SingleTestRunner escapes regex metacharacters in the `{name}` substitution

- behavior: `SingleTestRunner.runSingle` must execute exactly the target
  test when the behavior description contains regex metacharacters —
  `(sticky)`, `(FR-005)` — through a regex-flavored filter template
  (`dart test {file} -n "{name}"`), instead of failing with
  "No tests match regular expression" (exit 79,
  `RedClassification.runnerError`). The literal matcher `--plain-name`
  (issue #756) must keep receiving the raw, un-escaped name.
- tests: `test/plugins/tdd/services/runner_regex_escape_test.dart` (new,
  fast tier, two tests over a real `dart test` child in a TddFixture):
  - `-n` pin: green fixture behavior `maps (FR-005) to the request scope
    (sticky)` run through the `-n` template must exit 0 with testCount 1.
  - `--plain-name` guard: same behavior through the literal template must
    exit 0 with testCount 1 (green by definition pre-fix — characterization
    of the unchanged #756 contract).
- red: `dart test test/plugins/tdd/services/runner_regex_escape_test.dart`
  (pre-fix tree) -> 1 failed / 1 passed:
  - `-n` pin: `Expected: <0> Actual: <79>` — the runner's exit code for
    the target test was package:test's no-match signal.
  - direct CLI reproduction captured on the same pre-fix tree
    (`scripts/repro760.sh`, throwaway fixture):
    `dart test -n 'maps (FR-005) to the request scope (sticky)'` ->
    `No tests ran.` / `No tests match regular expression "maps (FR-005)
    to the request scope (sticky)".` exit 79 — the live production
    failure from the assessment. The same fixture with the escaped
    pattern `maps \(FR-005\) ... \(sticky\)` runs 1/1, exit 0.
- green: `_escapeRegExp` helper added in
  `lib/src/plugins/tdd/services/runner.dart`, applied to the `{name}`
  substitution in `_tokenize` when the template carries no
  `--plain-name` (regex-flavored filter). Re-run:
  `dart test test/plugins/tdd/services/runner_regex_escape_test.dart` ->
  2/2 passed. Regression sweep: `dart test test/plugins/tdd/runner_test.dart
  --preset=all` -> 9/9 passed; `dart test test/plugins/tdd/services/` ->
  233/233 passed; `tools/run_tests_chunked.sh` -> 66/66 chunks, 0 failures.
- refactor: none to the fix; formatter-only drift on 7 pre-existing
  lib/test files + 8 examples files cleaned via `dart format` (CI format
  gate parity, Dart 3.13.1 — the files fail the gate at master HEAD).
- `_substitute` (display/evidence) intentionally keeps the raw name: the
  U11 contract test pins `record.command` to contain the raw description,
  and the display is human-facing evidence, not the executed argv.
- deliberate mutants: recorded after the fix commit — see Cycle 2/3.
- commit: test(760) lands the test before fix(760) lands the source
  change; the test-only tree at test(760) still fails the `-n` pin.
