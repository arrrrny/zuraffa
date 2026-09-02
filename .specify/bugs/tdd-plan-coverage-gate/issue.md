# Bug Issue: [TDD-120] Coverage gate: plan must PROVE every FR and AC maps to a behavior (no silent spec gaps)

- **Slug**: tdd-plan-coverage-gate
- **Fetched**: 2026-09-02
- **Issue**: 846
- **URL**: https://github.com/arrrrny/zuraffa/issues/846
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

Context: '100% TDD built' is only claimable if the plan step proves completeness. Today plan emits A/U behaviors parsed from the spec; nothing fails when an FR/AC yields no behavior (e.g., malformed MUST sentence, table-format edge).

Required (system fix — a gate, not a report):
1. `zfa tdd plan` parses the spec contract strictly (TUPEC format: FR-xxx, AC-n, MUST/SHALL); any requirement statement that produces no behavior row = exit 2 with the offending spec line and `fix` instruction.
2. Plan artifact carries the traceability matrix (behavior ↔ FR/AC) and its hash; verify/corpus re-check the hash — spec edited after plan = exit 3 drift, re-plan required.
3. Acceptance criteria that are inherently non-automatable (e.g., 'feels fast') must be EXPLICITLY declared `manual` in the spec with an owner — undeclared non-automatable = exit 2. No silent drops.
4. Gap ledger from #836 becomes per-feature complete/total; corpus refuses 'complete' with open gaps.

## Comments

None.
