# Test List: 1480-spec-grammar-propagation

**Feature**: .specify/bugs/1480-spec-grammar-propagation (bug TDD mode, issue #1182 path resolution)
**Source**: spec.md (zuraffa-1.0) — derived via the LLM-guided fallback path (speckit.tdd.plan; engine detection: ZFA_MISSING — no `.zfa.json`, `zfa` not on PATH in this environment)
**Derived**: 2026-09-10T22:52:00Z

## Unit behaviors

| id | behavior | traces | criterion | state |
| -- | -------- | ------ | --------- | ----- |
| U1 | plan reads contract rows from contracts/*.md and routes traced unit behaviors as declared | PlanCommand, SpecParser | FR-001 | DONE |
| U2 | plan refuses unit-lane fallback (exit 1, no artifacts, spec untouched); --allow-unit-fallback restores legacy behavior | PlanCommand | FR-002 | DONE |
| U3 | init installs the zuraffa-1.0 spec template (absent → create, grammarless stock → replace, marked → untouched) | SpecTemplateWriter, InitCommand | FR-003 | DONE |
| U4 | criterion trace naming an unknown FR warns and never refuses | SpecParser | FR-004 | DONE |
| U5 | duplicate row names / double-declared traces refuse naming both sources | PlanCommand | FR-005 | DONE |

## Acceptance behaviors

| id | behavior | criterion | state |
| -- | -------- | --------- | ----- |
| A1 | speckit-authored spec + contracts file plans green with declared unit routing | AC-1 | DONE |
| A2 | all-fallback spec refuses at plan time in seconds (no 28-minute dead-end) | AC-2 | DONE |
| A3 | zfa tdd init leaves the project's spec-template carrying the grammar end-to-end | AC-3 | DONE |

## Coverage

- U1..U5 trace to FR-001..FR-005 (declared contract rows: PlanCommand, SpecParser, SpecTemplateWriter, InitCommand).
- A1..A3 trace to AC-1..AC-3.
- Out of scope (task constraints): engine cycle, gen/make pipeline, verify gate.

## Routing provenance

- route: U1..U5 -> unit lane [declared: contract row — zuraffa-1.0 grammar authored in spec.md]
- route: A1..A3 -> acceptance lane [declared: **Type** markers]
