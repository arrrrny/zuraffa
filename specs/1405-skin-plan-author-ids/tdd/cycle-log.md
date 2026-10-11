# Cycle log: 1405 — skin plan author strict W-ids + plan validator

## Cycle 1 — the format contract (U-1405-1 … U-1405-5)

- RED: `test/plugins/tdd/services/skin_plan_author_test.dart` load error —
  `SkinPlanAuthor` absent (evidence: tdd/red-evidence.txt).
- GREEN: `lib/src/plugins/tdd/services/skin_plan_author.dart` — strict
  `^W\d+$` pass-through, anchored leading-id rescue with orphan-paren
  cleanup, null for prose-only / mid-prose tokens, AC-class diagnosis
  precedence (no pattern → unmatched paren → spaces → generic), refusal
  lines with the `--> fix:` remedy.
- Result: 20/20 passed. REFACTOR: none needed (pure functions, documented).

## Cycle 2 — the plan-time wiring (A-1405-1 … A-1405-4, U-1405-6)

- RED: the CLI rows ran against the unfixed tree — 3 passed / 5 failed
  (the malformed declaration planned exit 0 and WROTE 04-SKIN.md; the
  contaminated token landed in the id column verbatim).
- GREEN: `PlanCommand._resolveLanes` sanitizes every non-derived SKIN
  declaration token through the author contract; a no-pattern token adds a
  validator refusal to the existing `_LaneResult.refusals` gate (exit 2
  before any artifact). Derived-behavior routing declarations
  (`W1, A3..A7` in the real example spec) and CORE/BOTH lanes pass through
  untouched — the first wiring attempt skipped the derived-check and
  `plan_skin_contract_1004_test.dart` caught it immediately (a real
  regression, fixed before commit; exactly what the regression rows exist
  for).
- Result: 8/8 passed + 59 lane/plan regression + 68 plan-touching suites.
- Mutation: A (validator neutered) killed by 10 rows; B (emission neutered)
  killed by 2 rows; restored tree 28/28 green.

## Verification

- tdd/verification.md — red/green tables, required plan-time validator
  checks (end-to-end exit codes), mutation evidence, gates, and the PROVED
  vs NOT ledger for the spec's success criteria.
