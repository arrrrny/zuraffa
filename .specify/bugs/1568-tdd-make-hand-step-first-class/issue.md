# Issue #1568 (verbatim source)

**Title**: tdd make hard-stops with generation-error on behaviors the planner already declared hand-step (entity-return contract subjects) — mechanical behaviors behind them become unreachable

**URL**: https://github.com/arrrrny/zuraffa/issues/1568

## Problem

The planner announces hand-step behaviors upfront (`Seam cost: 10 of 14 unit
behaviors will hand-step because return is an entity`), but `make` treats the
same condition as `generation-error` and stops the entire run. A feature with
any hand-step behavior can never drive its mechanical behaviors — the run
stops at the first hand-step, making remaining units/contracts unreachable.

## Root cause

Planner and driver disagree about the same behavior:

- **Planner**: predicts `hand-step` (entity-return contract subject, no
  mechanical implementation surface)
- **Driver/`make`**: treats the same condition as `generation-error` and
  stops (`fail fast`)

The subject is a `gen` contract-derived stub
(`ScanSession scan() => throw UnimplementedError(...)`, issue #1259) with no
generated implementation step for entity-returning contract subjects — unlike
the entity pipeline's `wire` + certified mock (#1498/#1500).

## Consequences

1. Feature with hand-step behaviors can never drive mechanical behaviors —
   run stops at first hand-step
2. Operator gets `generation-error` for a condition the tool itself
   classified as expected work
3. Resume re-drives everything up to the same wall (#1544's blocked-contract
   sibling)

## Discovered during

zxscan (barcode-scan host) dogfood, fresh project.

## Remediation

1. **First-class run state for hand-steps**: when planner marked a behavior
   hand-step, `make` reports `outcome=hand-step` (or `parked`) — non-fatal
   verdict that leaves behavior PENDING with honest red, records in run
   summary (`hand_steps=N`), lets run continue
2. **Honest classification**: hand-step out of scope = `deferred`-style
   transition (like `unexpressible` → `deferred (phase 2)`), never
   `generation-error`
3. **Report count at run end**: name hand-step behaviors in final summary so
   operator can implement them deliberately

## Acceptance criteria

1. `zfa tdd make` with hand-step behaviors reports `outcome=hand-step` (not
   `generation-error`) and continues to next behavior
2. Run summary includes `hand_steps=N` and lists the hand-step behavior IDs
3. Mechanical behaviors after hand-steps are reachable and drivable
4. Resume does not re-drive hand-step behaviors (they stay pending with
   honest red)

## Hard constraints

Fix the run state classification and hand-step propagation only. Do NOT
change the planner, the entity pipeline, or the analyze gate. One PR per
feature.

## Related

- #1565 (scaffold-step refusal)
- #1544 (blocked contract parks forever)
- #1551 (acceptance compose hard-stops on unmet precondition)
