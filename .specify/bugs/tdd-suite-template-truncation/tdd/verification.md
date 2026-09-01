---
feature: tdd-suite-template-truncation (bug #726, branch fix/726-tdd-suite-template-truncation)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: b66f11b2
behaviors: 7
proven: 7
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 6
criteria_covered: 6
mutation_score: 5/6 # scope: the six changed regex sites only; deliberate mutants (no mutation tool in profile)
mutants_survived: 1 # triaged: masked by sibling resolution site, MED finding below
suite: fast tier chunked 2527 passed / 0 failed (61 chunks, exit 0); feature scope test/plugins/tdd/ 369 passed / 0 failed (55s); slow-tier make_command_test.dart 24 passed / 2 failed (both PROVEN pre-existing at base 47d374c0)
---

# TDD Verification: bug #726 — loadSuiteTemplate truncates multi-word unquoted commands

**Verdict: PASS_WITH_GAPS.** All seven behaviors are `PROVEN` (red recorded in
the cycle log and corroborated by commit order: tests `0d52ba9c` land before
the fix `b66f11b2`), every acceptance criterion of the issue is covered, and
the full fast tier is green with zero new failures. The gaps: one surviving
deliberate mutant (single-loader nested fallback is masked by its sibling
site), and the audit was produced by the same session that wrote the tests,
so it is not an independent grading.

## Test-first evidence

The change ships exactly two commits, in TDD order:

| Commit | Content | Files |
| ------ | ------- | ----- |
| `0d52ba9c` | RED — 7 failing tests + cycle-log red evidence | `test/plugins/tdd/runner_suite_test.dart`, `test/plugins/tdd/make_command_test.dart`, `.specify/bugs/tdd-suite-template-truncation/tdd/cycle-log.md` |
| `b66f11b2` | GREEN — the fix, regex-only | `lib/src/plugins/tdd/services/runner.dart` (6 lines) |

Recorded red (cycle log, verbatim): runner-level run `+0 -6` with the issue
repro failing as `Expected: 'dart test' / Actual: 'dart'`; integration-level
`zfa tdd make` reproducing the issue's output verbatim (`suite baseline: dart`
→ `baseline exit: 0, failed: 0` → "the suite baseline did not produce a usable
snapshot"). History corroborates: the test commit precedes the fix commit and
touches no source file.

Diff-of-diffs check on pre-existing tests: the change adds tests only; no
assertion was removed, loosened, renamed, skipped, or excluded, and no
threshold was lowered (`git diff 47d374c0..HEAD --stat`: test files gain
+207 lines, source +6/−6).

| Behavior (new test) | Class  | Evidence |
| ------------------- | ------ | -------- |
| Keys block: unquoted multi-word suite mid-block | PROVEN | red in cycle log; test commit precedes fix commit |
| Keys block: unquoted multi-word suite (last key) | PROVEN | red: `StateError: no 'suite' command template found` |
| Nested stacks frontmatter: unquoted suite (issue repro) | PROVEN | red: `Expected: 'dart test' / Actual: 'dart'` |
| Nested stacks frontmatter: unquoted single | PROVEN | red: `Expected: 'dart test {file} …' / Actual: 'dart'` |
| Trailing comment captures command only | PROVEN | red: `Actual: 'dart'` |
| runSuite executes both words of the loaded template | PROVEN | red: output lacked `Dart SDK version: ` (bare-`dart` help instead) |
| `zfa tdd make` completes green on an unquoted profile | PROVEN | red: `outcome=runner-error`, "did not produce a usable snapshot" |

## Findings

| # | Severity | Finding | Evidence |
| - | -------- | ------- | -------- |
| 1 | MED | The nested-fallback `single:` site is not uniquely pinned: reverting it alone (mutant M4) is masked because the top-level anchored `single:` site resolves the same profile shape. A single-value trailing-comment test would pin it the way the suite path is pinned. | deliberate mutant M4, survived; suite-path counterpart is caught (see mutation table) |
| 2 | LOW | During authoring, the runSuite test's first assertion (`contains('Dart SDK version')`) was non-discriminating — the bare-`dart` help text also contains that phrase — and passed for a false reason pre-fix. It was strengthened to `contains('Dart SDK version: ')` before the red was recorded. Recorded because it is exactly the rubric's "would it catch a bug" failure mode. | bare `dart` prints `--version  Print the Dart SDK version.` |

No HIGH smells. Smell pass over the new tests: assertions are exact-value and
behavior-focused (no doubles, no re-implemented expectations, no conditional
logic, no tautologies); fixtures reuse the file's existing `_writeProfile`
helper and the `bug #NNN:` group convention established by the #681 group;
the integration test follows the file's `TddFixture` + `CliRunner` + fake
`zfa` bin conventions.

## Mutation results

No mutation tool in the profile (`mutation_test` is opt-in and not wired);
deliberate mutants per the rubric, scoped to the six changed regex sites,
one mutant in the tree at a time, each restored exactly and the group re-run
green afterwards. Sampled: 6 mutants.

| Mutant | Site | Change | Caught by | Judgment |
| ------ | ---- | ------ | --------- | -------- |
| M1 | suite, nested fallback | revert to old `[^\s#]+` | trailing-comment test (`Actual: 'dart'`) | caught; nested site is the sole resolver for comment-carrying values |
| M1b | suite, frontmatter top + nested | revert both to old class | issue-repro test (`Actual: 'dart'`) | caught; the reported truncation is pinned |
| M2 | suite, Keys block | separator `[ \t]+` → `\s+` (line-crossing) | mid-block test (`Actual: 'dart test\n…'` — the swallow begins) | caught; proves the line-bound separator is load-bearing. The literally-mandated `\S+(?:\s+\S+)*` variant fails this test — see remediation note in the PR |
| M3 | suite, nested fallback | token class → `\S` (drops `#` exclusion) | trailing-comment test (`Actual: 'dart test # the real suite'`) | caught; exactly the comment-swallowing risk the assessment flagged |
| M4 | single, nested fallback | revert to old `[^\s#]+` | none (survivor) | masked by the top-level anchored single site; behavior under test still holds for every tested shape → MED finding #1 |
| M4b | single, frontmatter top + nested | revert both to old class | single frontmatter test (`Actual: 'dart'`) | caught |

## Traceability

| Criterion (from issue.md / assessment.md) | Tests | End to end |
| ----------------------------------------- | ----- | ---------- |
| `loadSuiteTemplate` returns the full multi-word unquoted command | Keys mid-block, Keys last-key, issue repro | Yes (make integration) |
| `loadSingleTemplate` returns the full multi-word unquoted command | single frontmatter test | Via loader (same entry the CLI uses) |
| Quoted-value behavior unchanged (#681 regression guard) | existing U11/#681 groups (369-test feature suite green) | Yes |
| Trailing comments are not swallowed into the command | comment test | Via loader |
| `zfa tdd make` completes on a pure-Dart package with an unquoted profile | make integration test | Yes (real CLI, real `dart test` subprocess) |
| The full command reaches the process (not just the loader) | runSuite two-words test | Yes (real process) |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- The slow tiers beyond `make_command_test.dart` (`regression`,
  `integration`, `property`, `benchmark` presets): not run — `dart_test.yaml`
  prohibits the full slow tier on small/cloud agents (temp projects +
  `build_runner` fill several GB). The affected slow file was run in full.
- Coverage: opt-in per the profile, not run; mutation sampling is the
  strength evidence instead.
- The `- Full suite` bullet fallback path for unquoted values: untouched by
  the change (bullet values are backtick-wrapped) and not mutant-sampled.
- Independence: the audit was produced by the same session that wrote the
  tests, from a re-read of every file (Hard Rule 2 disclosure), not by a
  fresh-context reviewer.
- Performance and load behavior: no criterion, not assessed.
