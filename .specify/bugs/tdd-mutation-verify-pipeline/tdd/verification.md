---
feature: tdd-mutation-verify-pipeline (bug #837)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 2048458b # HEAD audited; the fix lands as this PR's single commit on top
behaviors: 5 # the five remediation points of the bug
proven: 4
likely: 1
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 5
criteria_covered: 5
mutation_score: 46 # scope: the two changed service files only, mutation_test 1.8.0
mutants_survived: 108 # triaged below: 1 MED (remediated in-cycle), rest LOW/accepted
suite: 69/69 chunked fast-tier folders OK; bug suite 10 unit + 4 CLI integration green
---

# TDD Verification: mutation verify pipeline (bug #837)

**Verdict: PASS_WITH_GAPS.** All five remediation behaviors are implemented,
tested through the real CLI surface, and covered end-to-end; the mutation
phase is now measured rather than assumed, which is exactly the gap this bug
existed to close. The verdict is not `PASS` because the audit was not
independent (same session wrote the fix and the tests), the mutation
measurement is scoped to the two changed service files with `verify_command`
unmeasured, and one MED survivor (the threshold `>=` boundary) was found and
remediated in-cycle but the full measurement was not re-run afterwards.

## Test-first evidence

The tests and the fix land in one commit (this PR). Per the rubric, a test +
source change in one commit is `PROVEN` only when the cycle log holds the
red; the red evidence for every behavior is recorded in
`tdd/cycle-log.md` (R-1 product reproduction, R-2 contract-test red) and was
captured in the same session before the fix was written.

| Behavior (remediation point)                            | Class  | Evidence                                                                     |
| ------------------------------------------------------- | ------ | ---------------------------------------------------------------------------- |
| 1. Preflight gate asserts GREEN (+ honest red refused)   | PROVEN | R-1 red (exit 64 on green) in cycle-log; C1 + C3 green                       |
| 2. Mutation executes, scoped to feature subjects         | PROVEN | R-2 compile red; `buildScopedMutationConfig` unit pins + C1 real mutation run |
| 3. Threshold gate from `.zfa.json`                       | PROVEN | unit threshold group + C4 real `.zfa.json` read                              |
| 4. Survivors → exit 1 + per-mutant report + `--> fix:`   | PROVEN | `parseMutationSurvivors` unit pins + C2 (exit 1, fix lines, per-mutant md)   |
| 5. spec-hash + subject-hash binding in artifacts         | LIKELY | binding unit test pins hash stability and rendering; no independent recompute audit of the sha256 inputs beyond the test |

No existing test was weakened, skipped, renamed out of a filter, or had an
assertion loosened (verified by reading the full diff of
`verify_command_test.dart`, `mutation_auditor_test.dart`,
`mutation_verifier_test.dart` against base b6afda42: zero modifications).
The only pre-existing behavior change is intentional and pinned by C3:
a gate-failure for survived/timeouted mutants moves from the 64 usage class
to exit 1 per the bug contract; preflight_red/not_assessed keep 64.

## Findings

| # | Severity | Finding                                                                                                                                 | Evidence |
| - | -------- | -------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| F1 | MED | Threshold boundary not pinned at equality: a `>=` → `>` mutant survived (score 0.9 vs threshold 0.8/0.95 cannot distinguish them) | `mutation_auditor.dart:477`; remediation: `score == threshold` boundary test added in-cycle (M-2, green); full re-measure not re-run |
| F2 | LOW  | ~50 survivors are markdown-rendering literals in `toMarkdown()` — the human report is under-pinned by the fast tier                      | `mutation_auditor.dart:163-264`; decisive sections are pinned by C1/C2 and the gate fields are asserted structurally |
| F3 | LOW  | `_parseCounts` legacy-version regex alternatives (pre-1.8 report shapes) unpinned — no per-version fixtures exist                        | `mutation_verifier.dart:266-295` |
| F4 | LOW  | Real-path subprocess glue (`_defaultPreflight`/`_defaultMutation`) unkillable by the fast tier because its unit tests use override seams; the real path is exercised only by the integration-tagged C1–C4, which the mutant test command excludes | `mutation_auditor.dart:519-575` |
| F5 | INFO | Incident: a time-killed measurement run left a `!(...)` negation mutant inside `MutationSurvivor.==` on disk; the unit suite caught it immediately and the line was restored exactly. Post-kill tree checks must be content-based, not diff-stat-based | cycle-log M-1 |

No `HIGH` smells from the catalogue in the new test file: assertions target
observable CLI output, exit codes, and written artifacts (not doubles,
internals, or re-implementations); no conditional assertion logic; no sleeps
or real clocks beyond bounded subprocess deadlines; setup duplication exists
(two unit groups build similar registry fixtures) — LOW, reported here
rather than silently ignored.

## Mutation results

Scope: the two changed service files (the repo-root mutation-test.xml scope
was deliberately not used: it mutates 21 TDD files, a CI-sized job). Tool:
mutation_test 1.8.0, config `<mutations version="1.0">`, mutant test command
`dart test <covering fast-tier files> -j 1` with per-mutant kernel-cache
cleanup (same contract as `tools/run-tdd-tests.sh`).

| File                              | Mutants | Detected | Survived | Timeouts | Not covered |
| --------------------------------- | ------- | -------- | -------- | -------- | ----------- |
| `services/mutation_auditor.dart`  | 110     | 47       | 63       | 0        | 0           |
| `services/mutation_verifier.dart` | 90      | 45       | 45       | 0        | 0           |
| total                             | 200     | 92       | 108      | 0        | 0           |

Survivor triage (judgment, not the raw list): F1 MED (remediated); the rest
are F2/F3/F4 LOW-accepted — report strings, version-compat regex fallbacks,
and override-seam-protected glue. Every survivor line is executed by the
suite (Not covered = 0), so none of these are dead-code survivors; they are
pin-strength gaps in the fast tier, cross-checked where it matters by the
CLI integration tier.

## Traceability

| Criterion (bug remediation)                          | Tests                                                                                    | End to end |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------- | ---------- |
| 1. Gate asserts GREEN + evidence                      | C1 (green passes), C3 (honest red refused), R-1 repro                                     | Yes (real CLI) |
| 2. Mutation executes, subject-scoped, bounded         | `buildScopedMutationConfig` pins; C1 real run (killed=2, was_run=true)                    | Yes (real mutation_test) |
| 3. Threshold gate from `.zfa.json`                    | threshold unit group; C4 (real `.zfa.json` read)                                          | Yes (real CLI + config) |
| 4. Survivors → exit 1 + per-mutant + `--> fix:`       | `parseMutationSurvivors` pins; C2 (exit 1, fix lines, `## Survived mutants` in artifacts) | Yes (real CLI) |
| 5. spec-hash + subject-hash binding                   | binding unit group; C1 asserts the rendered binding sections                              | Unit + artifact read |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- `verify_command.dart` (110-line diff) was NOT mutation-measured: its
  behavior is pinned by the subprocess-level C1–C4 integration tests, which
  are too slow per-mutant for the mutant test command. Its mutants are
  unmeasured, not passing.
- The full scoped measurement was not re-run after F1's boundary test was
  added; the boundary mutant is killed by construction (assertion at exact
  equality) but that kill is not measured in the 46% score above.
- Coverage (`dart test --coverage`) was not run: the profile marks it
  opt-in, not a gate.
- Corpus-scale runtime was not measured beyond the fixture scale (2 subjects,
  200 mutants, ~12 min wall-clock for the scoped audit); the bounded
  wall-clock contract is enforced by #742's deadlines, not re-verified under
  a full corpus.
- The audit was performed by the same session that wrote the fix and tests;
  it re-read every diff and report from cold state, but it is not an
  independent audit.
