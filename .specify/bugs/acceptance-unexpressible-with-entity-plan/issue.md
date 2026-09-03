# GitHub Issue

- URL: https://github.com/arrrrny/zuraffa/issues/923
- Number: 923
- Filed: 2026-09-02
- Title: fix(tdd): acceptance behaviors (A*) are unexpressible even with entity-bearing plan — no generator surface for acceptance composition
- State: open
- Severity: high

## Summary

All 5 acceptance behaviors (A1-A5) in spec 004 report `outcome=unexpressible` at the make step and defer to phase 2. The deferred make in phase 2a re-attempts and also reports `unexpressible`. The acceptance behaviors never reach `green` because the generation planner has no surface to express an acceptance scenario with a real implementation.

## Reproduction

```bash
# Spec 004 with 5 acceptance + 8 unit behaviors:
zfa tdd run 004-cloud-agent-task-dispatch
# [run] A1 make -> unexpressible
# [run] A1 make -> deferred (phase 2)
# [run] A2 make -> unexpressible
# ... all A behaviors defer
```

The acceptance scenarios describe end-to-end flows (e.g. "A queued, unlocked work item is dispatched, set to `dispatched` status, and locked"). The planner has no generator surface for end-to-end acceptance behavior implementation.

## Root cause

The `zfa tdd compose` step (per #642, spec 052) only **composes** against already-green unit subjects. If the unit subjects are also stubs (return 0, int), the composed acceptance scenario runs the stubs and produces a meaningless result. The acceptance scenario can't be made green until the underlying unit subjects are filled with real business logic.

The acceptance behaviors are unexpressible because the planner needs:
1. A real `TaskBriefRenderer.render()` implementation (FR-001)
2. A real `BrowserDispatchClient.dispatch()` (FR-002)
3. A real `DispatchService.dispatch()` (FR-003/004/006/007)
4. A real credentials scope mechanism (FR-008)

These are all currently stubs (`return 0`). Until the unit behaviors have real business logic, the composed acceptance scenarios can't be made green.

## Expected

- The `zfa tdd compose` step should be able to use the entity-wired subjects (U behaviors with `wiredEntityAnchor = Task`) as a basis for acceptance composition, even when the unit subjects are stubs
- The planner should treat the acceptance path as expressible when the unit subjects are entity-wired, deferring the actual green transition to when the unit subjects are filled with real logic
- OR a new "scaffolded acceptance" path that wires acceptance scenarios against entity anchors + minimal stub unit subjects

## Actual

All 5 acceptance behaviors hit `unexpressible` at the make step and defer forever. The run state shows them as `red` indefinitely.

## Verification

- A `zfa tdd run` with all U behaviors entity-wired and green completes the A behaviors to `green` (via compose or some equivalent)
- The acceptance tests pass (or have honest red evidence for the parts that need real unit impl)

## Context

Discovered while running spec 004 with the full real-impl workflow (spec.md wording + .zfa.json plugins). All 8 U behaviors reached `green` via entity-wired subjects, but the 5 A behaviors stayed unexpressible. The 13-behavior run stopped at refactor phase (per #922) but the A behaviors are still `red` in the run state.

Following STOP-ON-ROADBLOCK from zuraffa/AGENTS.md.
