# Spec: 1007-contract-tests-first-class

**Issue**: https://github.com/arrrrny/zuraffa/issues/1007
**Type**: feature
**Status**: implemented

## Problem

A contract test is different from a unit test: it proves an
implementation satisfies a **declared contract**, not that a piece of
code does what its author said. This is the substrate for `zfa dream`
(#1010) — without contract tests, generated and hand-written code are
graded by different rules.

Before this spec: no contract test kind existed. `zfa tdd plan` derived
only acceptance/unit behaviors from spec prose; `zfa tdd gen` had no
contract lane; a failing test for a declared contract was graded RED
(the TDD loop's expected first state) and the cycle proceeded toward
GREEN — exactly the wrong verdict for an unsatisfied contract.

## Deliverable

1. New behavior kind `contract` (alongside `unit`, `widget`). Plan emits
   `contract:<id>` rows for every entity method, controller method and
   usecase declared in the spec's Layer Contracts section.
2. `zfa tdd gen` for contract behaviors generates a **contract test
   scaffold** (not an implementation test): the test enumerates the
   contract's cases and asserts the implementation satisfies them, plus
   a contract seam subject carrying the declared signature.
3. A failing contract test is `BLOCKED` status (distinct from `RED`),
   with a different receipt (`contract-blocked.<id>.json`, schema
   `contract-blocked.v1`, under `.zfa/receipts/`) — it blocks the cycle
   from proceeding to GREEN (the run driver parks the behavior at
   `BLOCKED`, never spawns make, and stops with `result=blocked`).
4. The corpus-economics gap ledger treats contract-test failures as
   highest-severity gaps (`severity: contract`, named first, counted on
   the `contract_gaps=` summary token).

## Hard constraints

- The contract test kind is ADDITIVE: existing unit/widget (and every
  other lane's) test semantics are unchanged; pre-1007 plan artifacts,
  ledgers and registries read back identically.
- One PR for this spec.

## Exit criteria (from the issue)

- `zfa tdd plan 004-login-ui` emits `contract:A1` (entity method
  contract) in the engine plan.
- `zfa tdd gen contract:A1` produces a contract test that enumerates
  method cases.
- A deliberately unimplemented method causes a `BLOCKED` (not `RED`)
  verdict.
