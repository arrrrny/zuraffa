---
feature: 049-tdd-run
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 075aab18 # short SHA audited
behaviors: 42
proven: 41
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 12
criteria_covered: 12
mutation_score: unmeasured # no mutation tool wired; 5 deliberate mutants sampled (4 caught, 1 survived then remediated and caught)
mutants_survived: 0 # after remediation F1
suite: 144 passed, 0 failed (fast, 6s) / 239 passed, 0 failed (--preset=all incl. slow, 3m47s)
---

# TDD Verification: `zfa tdd run`

**Verdict: PASS_WITH_GAPS.** Every behavior carries recorded red+green
evidence, every acceptance criterion reaches a test through the real CLI
entry point (in-process scenarios plus a real-`dart run` quickstart
smoke), and the deliberate-mutant sample found one test-strength gap that
was remediated and re-verified. The gaps that keep this from `PASS`:
mutation strength is sampled, not measured (no mutation tool is wired),
and the audit was run by the same session that wrote the tests (see
"What was not audited").

## Audit independence disclosure

The same session authored the code and ran this audit. Mitigations
applied: every file was re-read cold for the smell pass; every mechanical
check (suite runs, claimed-test existence, deliberate mutants, restore
verification) was executed from the live tree rather than recalled; the
mutation findings below are reproducible from the recorded diffs.

## Test-first evidence

The whole feature landed as one behavioral commit (`9986bfec`, repo
convention is feature-scale commits) plus a remediation commit
(`075aab18`). The rubric's same-commit rule is satisfied — test and source
changed together and the cycle log records each cycle's red verbatim — so
behaviors are classified `PROVEN` on the strength of the session-recorded
cycle log (`specs/049-tdd-run/tdd/cycle-log.md`, cycles 1–8), with the
caveat that per-cycle ordering rests on the log, not on per-cycle commits.

| Behavior   | Class          | Evidence                                                     |
| ---------- | -------------- | ------------------------------------------------------------ |
| A1..A12    | PROVEN         | cycle 1 red (usage error vs the misfire-stop stub, 13 failed) recorded verbatim; cycle 7 green; scenarios run through CliRunner + scripted fake step binaries |
| U1..U3     | PROVEN         | cycle 2 red (`UnimplementedError`, 5 failed) -> green         |
| U4..U6     | PROVEN         | cycle 3 red (`UnimplementedError`, 4 failed) -> green         |
| U7..U11    | PROVEN         | cycle 4 red (`UnimplementedError`, 8 failed) -> green         |
| U12..U18   | PROVEN         | cycle 5 red (`UnimplementedError`, 9 failed) -> green         |
| U19..U29   | PROVEN         | cycle 6 red (13 failed against the stub) -> green             |
| U30        | NOT_APPLICABLE | pre-existing `run_state_test.dart` (spec 041), green at baseline and re-verified after the model extension; not driven by this loop |

Checks on pre-existing tests: no assertion was removed, loosened,
renamed, skipped, or excluded by this feature. The only existing-file
edits are additive fixture extensions (`tdd_fixture.dart`) and a
whitespace-only `dart format` pass over 97 pre-existing drifted files
(verified non-semantic with `git diff --ignore-all-space
--ignore-blank-lines`), committed separately as `b8352205`. `tasks.md`
checkboxes agree with the test list: all 25 tasks ticked, all 42
behaviors DONE, verified mechanically.

## Findings

| # | Severity | Finding                                                                                         | Evidence / resolution                                                                                                    |
| - | -------- | ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| 1 | HIGH     | U23/A5 could not distinguish in-flight-marker handling from state-implied re-entry (mutant 4 survived) | Remediated in `075aab18`: both tests seed a crash during verify-red (state PENDING, marker verify-red) and assert re-entry at verify-red with zero redundant `gen` invocations; mutant re-run now caught |
| 2 | MED      | FR-008's read-only guarantee over `test/` and `lib/` was not pinned by any test                  | Remediated in `075aab18`: new driver test snapshots the fixture's test/lib trees across a full run via `checksumTestAndLib()` |
| 3 | MED      | PID-liveness tests (U10, A5, sc_016 SC-006) spawn real `sleep`/`sh` processes                    | Inherent to the behavior (process liveness cannot be doubled); deterministic in practice; noted, not acted on |
| 4 | LOW      | `seedThreeBehaviors` duplicated across `run_command_test.dart` and the three scenario files      | Consistent with the repo's per-file fixture convention (sc_001–004 do the same); a shared helper would couple suites |
| 5 | LOW      | The fake-zfa shell script exists in two places (fixture generator + quickstart smoke script)     | Test infrastructure only; the smoke script is session-scratch, not committed                                               |

No `HIGH` smells remain after remediation. The smell pass re-read all 9
new/changed test files against the catalogue: no assertion-free,
tautological, doubled-subject, over-mocked, vacuous, conditional-logic,
or always-skipped tests; no mystery guests beyond the recorded fixture
helper; no sleepy tests (the only `sleep` is a live-owner stand-in, not a
wait); naming and assertion style follow the repo's sentence-as-name
convention and the `CliRunner.runCapturing` pattern of sc_001–004.

## Mutation results

No mutation tool is wired in the profile (the `mutation-test.xml`
config scopes to the 041 writers), so per the rubric's fallback,
deliberate mutants were applied one at a time to the highest-risk
behaviors, each restored exactly and verified by a green suite re-run.

| Mutant                                                                  | Behavior        | Survived | Judgment                                                                                          |
| ----------------------------------------------------------------------- | --------------- | -------- | ------------------------------------------------------------------------------------------------- |
| `run_command.dart` `_reconcile`: disable DONE demotion                   | FR-003 / U21, A9 | No       | Caught by both the driver test and the acceptance scenario                                        |
| `run_command.dart`: `return` -> `break` on step failure (drive on)       | FR-007 / U24, A7 | No       | Caught by the failure matrix and A7's later-behavior assertion                                    |
| `step_runner.dart`: make succeeds on any exit-0 outcome                  | FR-002 / U14     | No       | Caught by U14's contract matrix                                                                   |
| `run_command.dart` `_stepsFor`: ignore the in-flight marker              | FR-005 / U23, A5 | **Yes**  | Real finding (F1): the tests' seeds coincided with the state-implied step. Remediated (`075aab18`); re-run caught by both |
| `run_state_store.dart` `refusalReason`: guard disabled                   | FR-006 / U10, SC-006 | No   | Caught by the unit test and the concurrent-run scenario                                           |

Sample: 5 mutants across 5 of the 11 functional requirements (FR-002,
FR-003, FR-005, FR-006, FR-007). The sample is not exhaustive; see "What
was not audited".

## Traceability

| Criterion | Tests | End to end |
| --------- | ----- | ---------- |
| US1.AC1 (drive to all-DONE)  | A1, U19, U25 | Yes — scenario + real-CLI quickstart smoke |
| US1.AC2 (idempotent re-run)  | A2, U28      | Yes |
| US1.AC3 (list grows)         | A3, U29      | Yes |
| US2.AC1 (resume at make)     | A4, U22      | Yes |
| US2.AC2 (kill mid-step)      | A5, U23      | Yes |
| US2.AC3 (corrupt state)      | A6, U9       | Yes |
| US3.AC1 (make unexpressible) | A7, U24      | Yes |
| US3.AC2 (failure report)     | A8           | Yes |
| US3.AC3 (evidence beats state) | A9, U21, U4–U6 | Yes |
| US4.AC1 (progress lines)     | A10, U25     | Yes |
| US4.AC2 (summary line)       | A11, U26     | Yes |
| US4.AC3 (exit-code contract) | A12, U27     | Yes |

Functional requirements: FR-001 (U1–U3, U19, U29, A1), FR-002 (U12–U18,
A1), FR-003 (U4–U6, U21, A9), FR-004 (U7, U20), FR-005 (U22, U23, U28,
A4, A5), FR-006 (U9, U10, A6, SC-006), FR-007 (U24, A7, A8), FR-008 (new
read-only driver test, U24 no-silent-retry matrix, A9), FR-009 (U25,
A10), FR-010 (U26, U27, A11, A12), FR-011 (U3, U17, misfire cases in
U24, A6). Every claimed test exists and runs (verified mechanically
against all 42 test-list rows; the one file-level reference, U30, points
at a passing 4-test file).

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- Mutation strength was measured by a 5-mutant deliberate sample, not a
  tool: FR-001, FR-008, FR-009, FR-010, FR-011 and the services' full
  branch space were not mutated. Wiring `mutation_test` for the 049 files
  is recorded as remediation task T026.
- Coverage was not run (profile records it as opt-in, not a gate).
- The audit was performed by the authoring session — the mitigations are
  listed under the independence disclosure, but an independent re-run of
  `/speckit.tdd.verify` from a cold session would be stronger.
- The real (non-fake) `make` and `refactor` step commands are unmerged
  stubs owned by specs 047/048; end-to-end runs against the real steps
  will only be possible once those merge. The driver's contract side is
  what these tests pin.
- Performance/load behavior: no criterion, not assessed.
