---
feature: tdd-runner-legacy-frontmatter-template
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: ea399d96
behaviors: 5
proven: 0
likely: 4
test_after: 1
not_applicable: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: n/a # no mutation tool run; 1 deliberate mutant (dotAll -> multiLine) SURVIVED — documented; the operative mutant (pre-#692 runner.dart) was caught by 4/5 tests
mutants_survived: 1
suite: fast tier 2509 passed / 0 failed (61 chunks OK, 5 slow-tier-only folders skipped); runner_suite_test.dart 13/13; dart analyze 0 issues; dart format 0 diffs on touched files
---

# TDD Verification: [zfa tdd] SingleTestRunner cannot find single/suite templates in legacy frontmatter YAML format (#681)

**Verdict: PASS_WITH_GAPS.** The bug scenario does not reproduce on the
branch: a profile whose `single:`/`suite:` keys live entirely inside a
`---...---` YAML frontmatter block — nested under `stacks:<label>:`, with
no `## Keys (machine-readable)` section — resolves through both
`loadSingleTemplate()` and `loadSuiteTemplate()`. The operative fix (the
`1b. Legacy frontmatter YAML block` extraction path with the nested-key
matcher, anchored with `dotAll: true` per the issue's remediation) is
present on master `ea399d96` (landed with PR #692, ahead of this bug's own
PR) but shipped with ZERO legacy-frontmatter coverage — no test on master
exercised a frontmatter-based profile at all. This branch adds the 5
regression tests that lock the behavior plus this verification. RED is
real and observed: against the pre-#692 runner
(`git show 1f8d4099:lib/src/plugins/tdd/services/runner.dart`), 4 of the
5 new tests fail with the issue's exact errors
(`Bad state: zfa tdd verify-red: no 'single' command template found ...` /
`Bad state: zfa tdd make: no 'suite' command template found ...`);
the pre-#692 file contains no frontmatter handling at all
(`rg -c frontmatter` → 0). Gaps: tests written after the fix commit
(test-after relative to master) → `LIKELY`, mitigated by the pre-fix
mutant; and one flag-level mutant SURVIVED, honestly documented below.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — `loadSingleTemplate` resolves `single:` from nested `stacks:` frontmatter (no Keys block) — the issue's exact profile shape | LIKELY | pre-#692 runner: FAILS with `Bad state: zfa tdd verify-red: no 'single' command template found in .../tdd-profile.md` (the issue's step-4 error, byte-for-byte); green on the branch → `'dart test -n "{name}"'` |
| B2 — `loadSuiteTemplate` resolves `suite:` from the same nested shape | LIKELY | pre-#692 runner: FAILS with `Bad state: zfa tdd make: no 'suite' command template found ...`; green on the branch → `'dart test'` |
| B3 — a flat top-level `single:` in frontmatter also resolves | LIKELY | pre-#692 runner: FAILS (same missing-path error); green on the branch |
| B4 — the `## Keys (machine-readable)` block still wins over the frontmatter (resolution order preserved) | TEST_AFTER | passed pre-fix too (the Keys path predates the bug) — a precedence guard, not red-first |
| B5 — a frontmatter whose body contains a column-0 `---` line before the keys does not truncate the capture (the issue's stated multiLine mechanism) | LIKELY | pre-#692 runner: FAILS (no path at all); green on the branch. NOTE: this test does NOT distinguish `dotAll` from `multiLine` — see mutation findings |

No pre-existing test was weakened: no assertion removed, loosened, renamed,
skipped, or filtered; no threshold lowered. The 8 pre-existing
`runner_suite_test.dart` tests (Keys-block resolution, bullet fallback,
runSuite contracts) pass unchanged alongside the 5 new ones.

## Findings

Ordered by severity.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | The operative fix (frontmatter extraction path + nested matcher, PR #692 commit `ea399d96`) predates the bug's own PR and shipped with no frontmatter-based profile test anywhere in the suite. This branch closes that gap | `git show 1f8d4099:...runner.dart` has zero `frontmatter` occurrences; 4/5 new tests fail against it |
| 2 | MED | Deliberate mutant `dotAll: true` → `multiLine: true` on both frontmatter block regexes SURVIVED (all 5 new tests still green). Analysis: for this pattern (`^---\n([\s\S]*?)\n---`), the two flags are behaviorally EQUIVALENT whenever the frontmatter starts at string position 0 — `firstMatch` scans start positions left-to-right, start 0 wins in both modes, and the non-greedy capture to the first `\n---` is identical. `multiLine`'s extra power (matching a start mid-file) only adds matches; `dotAll` never succeeds where `multiLine` fails. The issue's stated mechanism ("stops at the first `\n---`, capturing only `detected_at`") requires a column-0 `---` INSIDE the block — and both flags stop there identically. The tests therefore lock the BEHAVIOR (legacy frontmatter resolves), not the flag; the `dotAll` flag is anchoring hygiene, not the operative change. Recorded so a future reader does not mistake the flag swap for the fix | mutant applied to both loaders, 5/5 green, restored byte-identical, suite re-run green |
| 3 | LOW | Robustness note, out of scope: with `dotAll` (no `multiLine`), a profile whose frontmatter is preceded by a leading blank line/BOM would NOT match (`^` anchors to string start), while `multiLine` would have matched it. No such file shape exists in the reported corpus; noted for a future normalization step in `_readProfile` | regex semantics as analyzed in finding 2 |

## Mutation results

No mutation tool run. Two deliberate mutants, one at a time, each restored
byte-identically (saved copy), suite re-run green after each restore:

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| pre-#692 runner.dart (the bug as shipped: no frontmatter extraction path) | B1–B3, B5 | No | 4/5 tests failed with the issue's exact `Bad state` errors; restored → 13/13 green |
| `dotAll: true` → `multiLine: true` on both frontmatter regexes (the issue's stated bug pattern) | B1–B5 | **Yes** | flags are equivalent for frontmatter at string start (see finding 2); the mutant exposes that the issue's mechanism description does not match regex semantics — recorded honestly rather than claiming a catch that did not happen |

2 mutants sampled: 1 caught, 1 survived (analyzed and documented). Not
exhaustive beyond these sites.

## Traceability

| Issue criterion (Expected Behavior) | Behaviors | Tests |
| ----------------------------------- | --------- | ----- |
| `single:` resolved from the `## Keys (machine-readable)` block (pre-existing ✅) | B4 | `the Keys (machine-readable) block still wins over the frontmatter` + pre-existing U11 tests |
| `single:` resolved from legacy frontmatter at top level | B3, B5 | `resolves a flat top-level single: in frontmatter`, `a frontmatter containing a horizontal rule ...` |
| `single:` resolved from legacy frontmatter at `stacks:<label>:single:` | B1 | `resolves single: from nested stacks frontmatter (no Keys block)` |
| Same for `suite:` | B2, B1 | `loadSuiteTemplate resolves suite: from nested stacks frontmatter` |

Every criterion maps to at least one test through the real entry point
(`SingleTestRunner.loadSingleTemplate` / `loadSuiteTemplate` — the exact
APIs `verify-red`, `make`, and `run` call). No test traces to nothing.

## What was not audited

- The `flutter`-tagged tier and the slow `runner_test.dart` suite (real
  `dart test` subprocess runs) — the unit-level contract above is the
  regression surface this bug touches; the slow suite was not re-run for
  this report.
- `mutation_test` scores — not configured/run for this service.
- End-to-end `zfa tdd verify-red`/`make`/`run` CLI invocations against a
  legacy-frontmatter project on disk (the loaders are exercised directly;
  the CLI wiring around them is unchanged by this bug).
- CI workflows; all counts are from local runs in this session
  (Dart 3.13.2 / Flutter 3.47.2 stable, Linux x64).
