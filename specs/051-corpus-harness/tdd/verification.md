---
feature: 051-corpus-harness
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 61d228f7 # short SHA audited (post remediation T033-T037)
behaviors: 48
proven: 48
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 14
criteria_covered: 14
mutation_score: n/a # no mutation tool in profile; deliberate-mutant sampling used
mutants_sampled: 7 # all caught, 0 survived; U11 below was not a mutant
suite: 2328 passed, 0 failed (fast tier, 64 chunks, runner exit 0) + 43 corpus slow-tier tests (preset=all), all green
remediation: T033-T037 complete (cycles 15-22) — the prior FAIL verdict's six TEST_AFTER behaviors now carry re-established reds
---

# TDD Verification: `zfa tdd corpus` — batch driving, verify gate, provenance audit, gap ledger

**Verdict: PASS.** The first audit (at `cbcd82e2`) failed closed on six
TEST_AFTER behaviors (A2, A5, A6, A10, A11, A12) whose implementations
had shipped inside cycle 7's driving-loop batch before their specific
tests were written. Remediation task T033 re-established a red for each
one — the behavior's implementation was reverted to its pre-cycle-7
shape, the test observed failing with the failure output recorded, and
the implementation restored byte-exact — recorded as cycles 15–20 in
`tdd/cycle-log.md`. All 48 behaviors are now PROVEN test-first; no HIGH
smell exists; every criterion is covered end-to-end.

The audit was run by the same session that wrote the tests (no fresh
context available in this environment); every file cited below was
re-read from disk for this report rather than recalled.

## Test-first evidence

| Behavior(s) | Class     | Evidence |
| ----------- | --------- | -------- |
| U1–U18 (models, stores, step runner) | PROVEN | cycles 2–6: red recorded against `UnimplementedError` stubs (commands quoted in the cycle log); history shows each test file and its implementation landing in the same per-cycle commit |
| A1, A3, A4, U19–U24 | PROVEN | cycle 7: the 8 command tests observed red against the T001 usage-printing skeleton (`Actual: []`, exit-code mismatches quoted), then the loop implemented |
| A2, A11 | PROVEN | remediation cycles 15 + 19: resume-skip revert -> `Expected: length of <2>` on the f1 argv log; resolution-append revert -> `Expected: length of <2>` on the ledger (only gap-001, no resolution); both restored byte-exact, +18 green |
| A5 | PROVEN | remediation cycle 16: gate-stop revert (every outcome absorbed as done) -> all 4 gate-matrix tests failed `Expected: <1> Actual: <0>`; restored, green |
| A6 | PROVEN | remediation cycle 17: waiver lookup removed -> 2 of 3 waiver tests failed (`Expected: <0> Actual: <1>` stopped; re-drive length), the foreign-gate test correctly still passed; restored, green |
| A10 | PROVEN | remediation cycle 18: ledger behavior-field revert -> SC-020 failed `Expected: 'B-002' Actual: <null>`; restored, green (specs-tree half already mutation-proven, cycle 8) |
| A12 | PROVEN | remediation cycle 20: report totals/blocking lines removed -> `Expected: contains 'ledger: found=1 filed=0 merged=0 blocking=1'` missing; restored, green |
| U25–U32 (scanner, audit) | PROVEN | cycles 11–12: reds recorded against the scanner stub and the usage-printing audit skeleton |
| A7, A8, A9 | PROVEN | cycle 12: 4 audit-command tests observed red (help text in `Actual`) |
| A13, A14, U33, U34 | PROVEN | cycle 13: 4 status-command tests observed red |

No existing test was weakened, skipped, or filtered out by this feature
(diff vs master touches no pre-existing test beyond the smoke test's
additive corpus expectations). The remediation splits (T034/T035) kept
every original assertion — only reorganized into named tests.

## Findings

All five findings from the first audit are resolved (T033–T037, cycles
15–22).

| #  | Severity | Finding | Resolution |
| -- | -------- | ------- | ---------- |
| 1  | HIGH (verdict-blocking) | 6 behaviors TEST_AFTER (A2, A5, A6, A10, A11, A12) | T033 cycles 15–20: each implementation reverted to pre-cycle-7 shape, red observed and quoted, restored byte-exact (`git diff` clean after all six); +18 green proof run |
| 2  | MED | SC-020 was one long eager test (~25 assertions) | T034: split into 7 phase-scoped tests sharing one fixture lifecycle (`setUpAll`/`tearDownAll` + closure state); a failing phase names itself — phase labels verified in runner output |
| 3  | MED | The A1 contract test asserted five observables in one test | T035: split into 5 per-observable tests (order / exit / persistence / gate / summary), each name stating its observable |
| 4  | LOW | `GapLedgerStore` timestamps were `DateTime.now()` — unasserted, future-flake risk | T036: clock injected (`clock: DateTime Function()`, defaults to wall clock), test-first (compile red quoted); fixed-stamp assertion `2026-08-31T12:00:00.000Z` + default-wall-clock bounds test |
| 5  | LOW | Two fake-zfa fixture dialects (corpus fixture vs `TddFixture.writeFakeZfaBin`) | T037: corpus fixture rewritten onto the canonical conventions — `LOG`-variable append, `ARGV="$*"` header, `if [[ "$ARGV" == *"<pattern>"* ]]` dispatch blocks, `set -e`; `shellQuoteInner` no-op removed. First-run red (prefix-match vs `tdd`-prefixed argv -> 23 failures) root-caused from failure output and fixed to substring match; all 43 corpus tests green |

No HIGH smells (assertion-free, tautological, doubled-subject,
vacuous, conditional-logic, always-skipped): none found. The spawner /
fake-zfa doubles sit at the process boundary BY DESIGN (the 049
contract); the subjects under test (runner logic, stores, scanner,
commands) are never doubled.

## Mutation results

No mutation tool is wired in this repo's profile; deliberate mutants on
the highest-risk behaviors, per the rubric's fallback. Sample: 7
behaviors of 48 (not exhaustive).

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| resume-skip removed (done features re-driven) | A2 | No | caught by the 0-duplicate-invocation assertion (now also a recorded red, cycle 15) |
| stray write into `specs/<f>/tdd/runner-junk.txt` | A10 | No | caught by the SC-020 specs-tree checksum |
| `verifyResult.success \|\| true` (every gate absorbed) | A5 | No | 4 gate-matrix tests failed (now also a recorded red, cycle 16) |
| waiver matched on feature only (gate ignored) | A6 | No | the different-gate test failed |
| blocking-gap listing suppressed in the report | A12 | No | the totals+naming test failed (now also a recorded red, cycle 20) |
| stop-propagation `break` removed | U23/A3 | No | the stop test failed (f2/f3 spawned) |
| resolution entries never appended | A11 | No | the resume test failed (ledger length 1; now also a recorded red, cycle 19) |
| ledger-totals blocking definition | U11 | — | not a mutant: the first test draft expected 1 blocking gap; the data-model definition (filed-but-unmerged still blocks) was applied and the expectation corrected before implementation was accepted — recorded in cycle 5 |

All 7 mutants were restored exactly and verified by re-running the
suite green after each restore.

## Traceability

| Criterion | Tests | End to end |
| --------- | ----- | ---------- |
| US1.AC1 | A1 (+ U19–U24 units) | Yes (CliRunner → corpus run; sc_020) |
| US1.AC2 | A2 | Yes (sc_020 + resume test) |
| US1.AC3 | A3 (via U23) | Yes |
| US2.AC1 | A4 | Yes |
| US2.AC2 | A5 (4 gate values) | Yes |
| US2.AC3 | A6 (3 waiver tests) | Yes |
| US3.AC1 | A7 (+ U25–U30) | Yes (CLI audit command) |
| US3.AC2 | A8 | Yes |
| US3.AC3 | A9 | Yes (carve-out flip) |
| US4.AC1 | A10 (checksum + U23 fields) | Yes |
| US4.AC2 | A11 | Yes (ledger byte-stability) |
| US4.AC3 | A12 | Yes |
| US5.AC1 | A13 (+ U33 read-only) | Yes |
| US5.AC2 | A14 (contract line + exits) | Yes |

Untested criteria: none. Tests tracing to nothing: none (all 48 rows
resolve to criteria/FRs/SCs; every claimed test file exists and runs —
43 slow-tier + fast-tier corpus assertions green).

## What was not audited

- Mutation was sampled (8 deliberate mutants on the highest-risk
  behaviors), not exhaustive; no mutation tool is configured in this
  repo.
- The audit session is the authoring session (no independent
  fresh-context subagent was available in this environment); every
  cited file was re-read from disk instead.
- `dart test --preset=all` heavy tiers (regression/integration/property/
  benchmark) were not run wholesale — the repo's dart_test.yaml and
  cloud-agent disk budget forbid them here; the corpus slow tier ran
  scoped (43 tests green via `--preset=all` on the five corpus files)
  and the full fast suite ran chunked (2328 green, 64/64 chunks,
  runner exit 0).
- Performance at 120-feature scale was not measured (no criterion pins
  a wall-time; the data model's assumption "no database, per-feature
  state files suffice" is untested at scale).
- The driven-app contract beyond the fake-zfa boundary (real `zfa tdd
  run`/`verify` behavior) is consumed as merged, per spec Out of Scope;
  only the machine-line parsing was tested, not the real commands'
  emission.
