---
feature: tdd-plan-coverage-gate
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 413ff7eb
behaviors: 6
proven: 0
likely: 6
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: n/a # no mutation tool; deliberate mutants 3/3 caught (plan gate disabled, drift gate disabled, corpus refusal removed), all restored byte-identical and re-run green
mutants_survived: 0
suite: fast tier chunked ~2648 passed / 0 failed (68 chunks: 62 in run 1 + 1 re-run + 5 batch; 5 chunks SKIP — slow-tier-only folders by design); affected area test/plugins/tdd 431/431; affected-area slow tier sc_018 plan→run e2e green (5:26, real pipeline with the gate in path); sc_021 FAILS IDENTICALLY ON CLEAN MASTER b6afda42 (pre-existing, verified via clean worktree)
---

# TDD Verification: coverage gate — plan must PROVE every FR/AC maps to a behavior (#846)

**Verdict: PASS_WITH_GAPS.** The bug's acceptance — a requirement statement
that produces no behavior row FAILS the plan loudly instead of silently
vanishing, the plan artifact carries the traceability proof, and the corpus
can no longer claim `complete` over open gaps — is proven by 9 command-level
tests + 20 unit tests, all RED first for the exact pre-fix signatures
(exit 0 on silent drops; no traceability artifact; manual AC still emitted
as a behavior row; `result=complete` with `blocking=0` over an open gap on a
done feature) and GREEN after the fix. sc_018 (the real-pipeline loop e2e)
passes with the gate in the plan path, so the gate does not break the loop it
polices. Gaps: test-first evidence is `LIKELY` (the RED batch ran in-session
before any fix code existed — 8/9 failing for exactly the predicted reasons —
but test + fix land in one commit per repo convention, so git history alone
cannot show ordering), and mutation was the deliberate-mutant procedure
(3 mutants sampled on the three gate seams; no mutation tool in the profile).

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — strict TUPEC scan: FR/AC statements recognized in defining positions (canonical bullet, malformed `**FR-n:**`, heading, table row; scenario headers; NOT mid-sentence references) | LIKELY | `requirement_scan_test.dart` 7 scanner tests; RED: `| FR-002 | MUST ... |` and `**FR-002:**` produced no row and exit 0 |
| B2 — plan coverage gate: any statement with no behavior row = exit 2, offending line + fix instruction, NO artifacts written | LIKELY | `bug_846_coverage_gate_test.dart` 4 gate tests (malformed bullet, table FR, unparseable AC, ownerless manual) — all RED at exit 0, GREEN at exit 2 with `test-list.md` asserted absent |
| B3 — traceability artifact: matrix (requirement ↔ behavior, per-line status) + sha256 spec-contract hash written on success | LIKELY | "successful plan writes matrix + spec hash" (RED: file absent); hash stability unit tests (stable under prose edits, flips on contract edits) |
| B4 — manual AC declaration: `(manual: @owner)` scenario excluded from the automated loop, marked manual in the matrix; ownerless declaration = exit 2 | LIKELY | manual-marker test (RED: `A2` row present pre-fix); ownerless-declaration test (RED: exit 0) |
| B5 — drift gate: verify re-checks the plan hash; spec edited after plan = exit 3 + re-plan instruction; unchanged spec passes through to the audit | LIKELY | drift test (RED: exit 0) + pass-through test (asserts `isNot(3)`) |
| B6 — corpus refuses `complete` with open gaps (any unresolved gap, regardless of feature state) + per-feature complete/total coverage from the traceability artifact | LIKELY | status-level test (RED: `result=complete` with `blocking=0` over an open gap on a done feature) + 2 `GapLedgerTotals.open` unit tests pinning open-vs-blocking semantics |

No pre-existing test was weakened or loosened — the test diff is additions
only plus two new files; `gap_ledger_store_test.dart` gains a group and loses
nothing (`git diff` shows no removed assertions). Existing `spec_parser_test`
expectations (single-story `AC-1`/`AC-2` ids) hold unchanged under
document-wide AC numbering; `plan_gen_contract_test` (the 4-column canonical
shape) passes untouched; sc_018 proves the plan→gen→run contract end to end.

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | The corpus RUN-level complete-refusal branch (corpus_run_command.dart) has no direct test — the status-level refusal and the shared `totals.open` semantics are covered, but the run-level branch (refusal print + result flip after a full drive) could regress silently | `corpus_run_command.dart` `_complete` call site; no test drives corpus run to all-done with an open ledger gap (run spawns subprocesses; fixture cost deliberately out of this bug's scope) |
| 2 | LOW | Document-wide AC numbering renumbers acceptance rows for multi-story specs (previously duplicated `AC-1..2` per story); a re-plan rewrites those `traces` values and plan's id-reconciliation falls through to the new ids. Migration is a re-plan — the issue sanctions re-plans ("strict parsing may reject previously-accepted specs") but existing multi-story test lists will diff on re-plan | `spec_parser.dart` flush() id derivation; `spec 009` has 3 stories → AC ids change on next plan |
| 3 | LOW | The `(manual: @owner)` convention is documented only in parser/fix-instruction text and the matrix itself — no `docs/` or CLI_GUIDE page (minimal-change constraint: one PR, gate code + tests only) | `spec_parser.dart` doc comment; `requirement_scan.dart` fix strings |
| 4 | LOW | Unanchored normative sentences (MUST/SHALL with no FR/AC id and no defining position) are invisible to the gate by design: statement-position recognition is deliberately conservative to avoid false positives on mapping tables (calibrated against spec 015, whose FR-mapping table must stay plannable). TUPEC anchoring is therefore enforced per-statement, not per-MUST | `_statementPrefix` regex doc comment; 015 calibration checks in-session |

## Mutation results

No mutation tool in the profile; deliberate mutants, one at a time, each
restored byte-identical (`diff` vs pre-mutant copy: empty) and the focused
suite re-run green afterwards.

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| plan gate disabled (`if (false && gaps.isNotEmpty)`) — the bug's silent-drop anti-pattern reintroduced | B2 | NO — 4/9 gate tests fail (exit 2 assertions + no-artifact assertion) | caught by the command-level gate tests |
| drift gate disabled (hash compare short-circuits to `return null`) | B5 | NO — drift test fails (exit 3 expected, got 0) | caught by the drift test |
| corpus refusal removed (`!openGapRefusal` dropped from the complete predicate) | B6 | NO — status test fails (`result=complete` again) | caught by the status-level refusal test |

## Traceability

| Issue #846 criterion | Behaviors | Tests |
| -------------------- | --------- | ----- |
| 1. Strict TUPEC parsing; requirement → no behavior row = exit 2 with offending line + fix | B1, B2 | 4 gate tests + 7 scanner tests; fix strings assert `fix:` + TUPEC forms |
| 2. Traceability matrix + hash in the plan artifact; verify re-check = exit 3 drift, re-plan required | B3, B5 | matrix test, 3 hash tests, drift + pass-through tests; verify runs the check BEFORE the audit (drift short-circuits) |
| 3. Non-automatable ACs declared `manual` with owner; undeclared = exit 2 | B4 | manual-marker test (row excluded, matrix marks manual/owner) + ownerless test (exit 2) |
| 4. Per-feature gap ledger complete/total; corpus refuses `complete` with open gaps | B6 | status refusal test + 2 `GapLedgerTotals.open` unit tests + per-feature coverage line (status report) |

No criterion without a test; no test tracing to nothing.

## What was not audited

- The SLOW tier beyond sc_018/sc_021 (other scenario suites, regression /
  property / benchmark presets) was not run; `--preset=integration` over the
  whole tree overflows a 10 GB sandbox kernel cache (observed, cleaned), and
  the chunked fast runner excludes slow-tier folders by design.
- sc_021 is flagged, not fixed (auditor does not fix): "A2: the composed
  behavior's green evidence names the compose step" fails identically on
  clean master (verified in a clean worktree at b6afda42 with this branch's
  changes absent) — pre-existing composition e2e failure, unrelated to the
  plan pipeline (composition/compose step, zero file overlap with this fix).
- Mutation was sampled (3 deliberate mutants on the three gate seams), not
  exhaustive; no coverage run (the profile's coverage command was not
  exercised).
- The corpus run-level refusal path is untested (finding 1); the drift
  re-check inside corpus is inherited from verify via the step runner's
  non-zero-exit policy and was not separately e2e-driven.
- The audit is same-session (not independent): the tests were authored by
  the same session that wrote the fix; the smell pass is self-graded against
  the rubric and the tdd-profile exemplars.
