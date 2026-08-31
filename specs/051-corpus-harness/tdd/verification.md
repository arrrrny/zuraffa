---
feature: 051-corpus-harness
verdict: FAIL
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: cbcd82e2 # short SHA audited
behaviors: 48
proven: 41
likely: 0
test_after: 6
no_test: 0
high_smells: 0
criteria_total: 14
criteria_covered: 14
mutation_score: n/a # no mutation tool in profile; deliberate-mutant sampling used
mutants_sampled: 8 # all caught, 0 survived; 6 during the loop, 2 during this audit
suite: 2326 passed, 0 failed (fast tier, 64 chunks) + 33 slow-tier corpus tests, all green
---

# TDD Verification: `zfa tdd corpus` — batch driving, verify gate, provenance audit, gap ledger

**Verdict: FAIL.** Six behaviors (A2, A5, A6, A10, A11, A12) are
TEST_AFTER: their implementations shipped inside cycle 7's driving-loop
batch before their specific tests were written (cycles 8–10), so no red
evidence exists for them. The tests were proven to pin their behaviors
by deliberate mutants (all killed), every criterion is covered
end-to-end, and no HIGH smell was found — but the rubric's letter makes
any TEST_AFTER behavior a FAIL, and this audit fails closed.

The audit was run by the same session that wrote the tests (no fresh
context available in this environment); every file cited below was
re-read from disk for this report rather than recalled.

## Test-first evidence

| Behavior(s) | Class     | Evidence |
| ----------- | --------- | -------- |
| U1–U18 (models, stores, step runner) | PROVEN | cycles 2–6: red recorded against `UnimplementedError` stubs (commands quoted in the cycle log); history shows each test file and its implementation landing in the same per-cycle commit |
| A1, A3, A4, U19–U24 | PROVEN | cycle 7: the 8 command tests observed red against the T001 usage-printing skeleton (`Actual: []`, exit-code mismatches quoted), then the loop implemented |
| U25–U32 (scanner, audit) | PROVEN | cycles 11–12: reds recorded against the scanner stub and the usage-printing audit skeleton |
| A7, A8, A9 | PROVEN | cycle 12: 4 audit-command tests observed red (help text in `Actual`) |
| A13, A14, U33, U34 | PROVEN | cycle 13: 4 status-command tests observed red |
| A2, A11 | TEST_AFTER | cycle 8: the tests passed on first contact (the resume skip and resolution logic shipped in cycle 7's batch); the playbook's pass-on-first-run protocol was applied — resume-skip and checksum mutants killed — but no red exists |
| A5, A6 | TEST_AFTER | cycle 9: gate matrix + waiver tests green on first contact; absorb and broad-waiver mutants killed; no red |
| A10 | TEST_AFTER | cycle 8: the specs-tree checksum half of SC-020 passed on first contact; checksum mutant killed; no red (the six-field-entry half rides U23's PROVEN test) |
| A12 | TEST_AFTER | cycle 10: report-totals test green on first contact; blocking-list mutant killed; no red |

No existing test was weakened, skipped, or filtered out by this feature
(diff vs master touches no pre-existing test beyond the smoke test's
additive corpus expectations).

## Findings

Ordered by severity, each with evidence and the fix.

| #  | Severity | Finding | Evidence |
| -- | -------- | ------- | -------- |
| 1  | HIGH (verdict-blocking) | 6 behaviors TEST_AFTER (A2, A5, A6, A10, A11, A12): implementations landed in cycle 7's batch before their tests; only mutant kills, not reds, back them | `specs/051-corpus-harness/tdd/cycle-log.md` cycles 8–10 notes; commits cycle-7 vs cycles 8–10 |
| 2  | MED | SC-020 is one long eager test (drive → stop → resume → status preview removed) with ~25 assertions; a failure names the line but not which phase broke | `test/plugins/tdd/scenarios/sc_020_corpus_harness_e2e_test.dart:87-166` |
| 3  | MED | The A1 contract test asserts order, persistence, gate recording, summary line, and exit code in one test (five observables) | `test/plugins/tdd/commands/corpus_run_command_test.dart:47-75` |
| 4  | LOW | `lib/…/gap_ledger_store.dart` timestamps are `DateTime.now()` — unasserted (safe today), but any future timestamp assertion would flake | `lib/src/plugins/tdd/services/gap_ledger_store.dart:100` |
| 5  | LOW | The fake-zfa fixture's bash script embeds `kill`-style shell quoting helpers that duplicate the repo's `TddFixture.writeFakeZfaBin` dispatch style (two fixture dialects now exist) | `test/plugins/tdd/helpers/corpus_fixture.dart:79-104` |

No HIGH smells (assertion-free, tautological, doubled-subject,
vacuous, conditional-logic, always-skipped): none found. The spawner /
fake-zfa doubles sit at the process boundary BY DESIGN (the 049
contract); the subjects under test (runner logic, stores, scanner,
commands) are never doubled.

## Mutation results

No mutation tool is wired in this repo's profile; deliberate mutants on
the highest-risk behaviors, per the rubric's fallback. Sample: 8
behaviors of 48 (not exhaustive).

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| resume-skip removed (done features re-driven) | A2 | No | caught by the 0-duplicate-invocation assertion |
| stray write into `specs/<f>/tdd/runner-junk.txt` | A10 | No | caught by the SC-020 specs-tree checksum |
| `verifyResult.success \|\| true` (every gate absorbed) | A5 | No | 4 gate-matrix tests failed |
| waiver matched on feature only (gate ignored) | A6 | No | the different-gate test failed |
| blocking-gap listing suppressed in the report | A12 | No | the totals+naming test failed |
| stop-propagation `break` removed | U23/A3 | No | the stop test failed (f2/f3 spawned) |
| resolution entries never appended | A11 | No | the resume test failed (ledger length 1) |
| ledger-totals blocking definition | U11 | — | not a mutant: the first test draft expected 1 blocking gap; the data-model definition (filed-but-unmerged still blocks) was applied and the expectation corrected before implementation was accepted — recorded in cycle 5 |

All 8 mutants were restored exactly and verified by re-running the
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
33 slow-tier + 240 fast-tier corpus assertions green).

## What was not audited

- Mutation was sampled (8 deliberate mutants on the highest-risk
  behaviors), not exhaustive; no mutation tool is configured in this
  repo.
- The audit session is the authoring session (no independent
  fresh-context subagent was available in this environment); every
  cited file was re-read from disk instead.
- `dart test --preset=all` heavy tiers (regression/integration/property/
  benchmark) were not run — the repo's dart_test.yaml and cloud-agent
  disk budget forbid them here; the corpus slow tier ran scoped
  (33 tests green) and the full fast suite ran chunked (2326 green).
- Performance at 120-feature scale was not measured (no criterion pins
  a wall-time; the data model's assumption "no database, per-feature
  state files suffice" is untested at scale).
- The driven-app contract beyond the fake-zfa boundary (real `zfa tdd
  run`/`verify` behavior) is consumed as merged, per spec Out of Scope;
  only the machine-line parsing was tested, not the real commands'
  emission.
