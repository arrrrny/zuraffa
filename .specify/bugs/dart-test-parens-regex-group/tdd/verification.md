---
feature: dart-test-parens-regex-group (bug #760, slug tdd-parens-regex)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 7841c92
behaviors: 2
proven: 1
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 2
criteria_covered: 2
mutation_score: 100 # scope: {name} substitution in lib/src/plugins/tdd/services/runner.dart, 2 deliberate mutants, no mutation tool in profile
mutants_survived: 0
suite: fast tier chunked 66/66 chunks (61 PASS, 5 SKIP slow-tier-only), 0 failed; targeted 2 + 9 + 233 passed
---

# TDD Verification: bug #760 — dart test -n treats parens in the behavior name as a regex group

**Verdict: PASS_WITH_GAPS.** The fix's contract is pinned by a test that
landed in git history before the fix (recorded red: exit 79), no HIGH
smells, both criteria covered through the real runner entry point, and
both sampled mutants were caught. The gaps are process-shaped, not
evidence-shaped: this audit was not independent (same session wrote the
tests), no pre-fix full-suite baseline was captured, and mutation was a
2-mutant sample, not a tool run.

## Test-first evidence

| Behavior | Class           | Evidence                                                                                                                    |
| -------- | --------------- | --------------------------------------------------------------------------------------------------------------------------- |
| B-760-n — `{name}` is escaped for a regex-flavored filter (`-n`/`--name`)                    | PROVEN          | cycle 1 red recorded with output (`Expected: <0> Actual: <79>` plus the direct CLI repro `No tests match regular expression ...` exit 79); history: `0716ccc` (test-only commit) precedes `28b93cc` (fix commit); the test-only tree still fails the pin |
| B-760-plain — `--plain-name` keeps receiving the raw name (issue #756 contract, unchanged)   | NOT_APPLICABLE  | characterization of untouched behavior: green by definition at red time; landed in the same test commit as B-760-n                                                                          |

No existing test was weakened, skipped, renamed out of a filter's
reach, or excluded by config in this change. The style commit
(`7841c92`) touching 4 existing test files is formatter-only
rewrapping under the CI-pinned SDK 3.13.1; no assertions changed.

## Findings

| #   | Severity | Finding                                                                                                     | Evidence                                    |
| --- | -------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| 1   | MED      | No pre-fix full-suite baseline was captured in this session, so pre-existing vs new failures cannot be separated by a baseline entry | cycle-log Baseline: chunked suite ran post-fix only; mitigated by 0 failures across all 66 chunks at HEAD |
| 2   | LOW      | Audit not independent: run by the same session that wrote the fix and its tests (rubric Hard Rule 2)         | this report; smells re-checked from the files as written |

## Mutation results

No mutation tool in the profile (`.specify/memory/tdd-profile.md`:
"Mutation tool: none wired in CI"); deliberate-mutant sampling per the
rubric, one mutant at a time, restored exactly, suite re-verified green
after each restore. Sample: 2 mutants on the one changed behavior site.

| Mutant                                                                 | Behavior    | Survived | Judgment                                                                 |
| ---------------------------------------------------------------------- | ----------- | -------- | ------------------------------------------------------------------------ |
| `runner.dart:408` — escaping dropped (`escapeName ? _escapeRegExp(name) : name` → `name`)              | B-760-n     | No       | Caught by the `-n` pin: exit 79 reproduced, `Expected: <0> Actual: <79>`  |
| `runner.dart:403` — condition inverted (`!template.contains('--plain-name')` → `template.contains(...)`) | B-760-plain | No       | Caught by the guard (and the pin): 2/2 tests failed with exit 79          |

## Traceability

| Criterion (from issue #760)                                                                     | Tests                                                              | End to end |
| ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ | ---------- |
| AC-1: `dart test -n "<name>"` matches a metacharacter-bearing behavior name literally (no exit-79 runner-error) | `test/plugins/tdd/services/runner_regex_escape_test.dart` (`-n` pin) + direct CLI repro (escaped pattern → 1/1, exit 0) | Yes — real `SingleTestRunner.runSingle` spawning a real `dart test` child in a temp fixture |
| AC-2: the `--plain-name` literal matcher (issue #756) is not corrupted by escaping                | `test/plugins/tdd/services/runner_regex_escape_test.dart` (guard)   | Yes — same real-runner path                                                  |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- Full `zfa tdd verify-red` / `zfa tdd make` CLI invocation against a
  fixture feature with a parens behavior: the pin covers the substitution
  site through the real runner; the CLI plumbing around it is exercised
  by the 233 tests in `test/plugins/tdd/services/` but was not re-run
  with a metacharacter-bearing behavior name in this audit.
- Mutation via tool: none in the profile; the 2 deliberate mutants sample
  only the changed substitution logic, not the whole of `runner.dart`.
- Slow tiers (regression / integration / property / benchmark) and
  Flutter-tagged tests: excluded from the fast suite by `dart_test.yaml`
  and the chunked runner; not run on this cloud agent.
- `examples/` packages: Flutter SDK not installed here; the style commit
  touches them with `dart format` output only, no behavior audit.
- Coverage: profile marks it opt-in ("not a gate"); not run.
- The `verify-red` classification path (exit 79 → `runnerError`) is
  asserted in existing tests (`U13`, subprocess timeout suite) and was
  not re-derived here.
