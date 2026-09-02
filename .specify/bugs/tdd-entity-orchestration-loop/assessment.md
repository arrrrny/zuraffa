# Bug Assessment: entity orchestration inside the TDD loop — spec Key Entities → entity create → make → wire

- **Slug**: tdd-entity-orchestration-loop
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/829
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

The TDD loop never reads the spec's Key Entities. Agents must run `zfa entity create` manually; `zfa tdd wire` then refuses subjects it did not generate. The pure-function path produces empty subjects — it sidesteps the architecture. The REAL pipeline must generate the domain layer. https://github.com/arrrrny/zuraffa/issues/829

## Symptom

`zfa tdd plan` does not extract Key Entities from spec.md. `zfa tdd run` never runs `zfa entity create` for declared entities. Unit behaviors traced to an entity's FR cannot route to the entity pipeline. `zfa tdd wire` refuses subjects with "unrecognized shape". Empty subjects are generated instead of real domain entities.

## Reproduction

1. Spec declares Key Entities (e.g. `ZikZakConfig`, `Listing`)
2. `zfa tdd plan` does not extract them into the plan artifact
3. `zfa tdd run` skips entity creation — behaviors get empty subjects
4. Manual `zfa entity create` + `zfa tdd wire` fails with "unrecognized shape"

## Suspected Code Paths

- `zfa tdd plan` — does not parse Key Entities section from spec.md
- `zfa tdd run` phase 0 — no entity creation step
- `zfa tdd wire` — shape detection rejects valid UnimplementedError stubs
- Entity pipeline (usecases/repos/di) — never invoked by the TDD loop

## Root Cause Hypothesis

High confidence: the TDD loop was designed for pure-function generation and never integrated the entity pipeline. Plan doesn't extract entities, run doesn't create them, and wire's shape detection is too strict for current stubs.

## Proposed Remediation

**Preferred**: (1) `zfa tdd plan` extracts Key Entities from spec.md into the plan artifact. (2) `zfa tdd run` phase 0: idempotent `zfa entity create` + `zfa build` before behaviors. (3) Unit behaviors traced to entity FRs route to entity pipeline. (4) Fix wire shape detection. (5) Idempotent entity reuse — never overwrite without `--force`.

**Alternatives** (optional):
- Manual entity creation before TDD run — the current workaround; doesn't scale to 120 specs.

**Files likely to change**:
- Plan command (entity extraction)
- Run command (phase 0 entity creation)
- Wire command (shape detection fix)
- Test suite

**Tests to add or update**:
- Plan extracts entities from spec with Key Entities section
- Run creates entities before driving behaviors
- Wire accepts current gen'd stub shape
- Entity reuse: existing entity not overwritten

## Risks & Considerations

- Entity creation must be idempotent — never overwrite hand-tuned fields
- Wire shape detection must accept valid stubs without false negatives
- 60+ specs affected (all data-bearing specs)
- Depends on #827 (artifact namespacing) for correct paths

## Open Questions

- [NEEDS CLARIFICATION: Should entity extraction use AST parsing or regex on the spec markdown?]
- [NEEDS CLARIFICATION: What is the correct stub shape that wire should accept?]
