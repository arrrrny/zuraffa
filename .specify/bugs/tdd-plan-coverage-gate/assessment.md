# Bug Assessment: coverage gate — plan must PROVE every FR and AC maps to a behavior

- **Slug**: tdd-plan-coverage-gate
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/846
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd plan` emits behaviors parsed from the spec but nothing fails when an FR/AC yields no behavior. Malformed MUST sentences, table-format edges, and non-automatable ACs are silently dropped. The 100% TDD claim is not backed by a completeness proof. https://github.com/arrrrny/zuraffa/issues/846

## Symptom

`zfa tdd plan` silently drops requirements that don't parse into behavior rows. No exit code signals incomplete coverage. Non-automatable ACs are not declared. The gap ledger from #836 is not per-feature. Corpus can report 'complete' with open gaps.

## Reproduction

1. Spec has a malformed MUST sentence or table-format FR
2. `zfa tdd plan` runs — no behavior row generated for that requirement
3. No error, no exit code — silent drop
4. Corpus reports 'complete' despite missing coverage

## Suspected Code Paths

- `zfa tdd plan` — spec parsing logic, no strict contract enforcement
- Plan artifact — no traceability matrix, no hash binding
- Verify/corpus — no re-check of plan completeness
- Gap ledger — not per-feature, not enforced

## Root Cause Hypothesis

High confidence: plan was designed as a parser, not a gate. It extracts what it can and silently skips what it can't. There is no strict contract enforcement, no traceability matrix, and no hash binding to detect spec drift.

## Proposed Remediation

**Preferred**: (1) Strict TUPEC parsing: FR-xxx, AC-n, MUST/SHALL — any requirement producing no behavior row = exit 2 with offending line + fix instruction. (2) Traceability matrix in plan artifact with hash; verify/corpus re-check hash — spec edited after plan = exit 3 drift. (3) Non-automatable ACs must be declared `manual` with owner — undeclared = exit 2. (4) Per-feature gap ledger; corpus refuses 'complete' with open gaps.

**Alternatives** (optional):
- Loose parsing with warnings — doesn't enforce the 100% claim; not acceptable.

**Files likely to change**:
- Plan command (strict TUPEC parsing, traceability matrix)
- Verify/corpus (hash re-check)
- Gap ledger (per-feature enforcement)
- Spec format (manual AC declaration)

**Tests to add or update**:
- Malformed MUST → exit 2 with offending line
- Spec edited after plan → exit 3 drift
- Undeclared non-automatable AC → exit 2
- Corpus with open gaps → refuses 'complete'

## Risks & Considerations

- Strict parsing may reject previously-accepted specs — migration path needed
- Traceability matrix hash must be lightweight
- Manual AC declaration requires spec format convention
- All 120 specs affected

## Open Questions

- [NEEDS CLARIFICATION: What is the exact TUPEC format for FR/AC parsing?]
- [NEEDS CLARIFICATION: Should the traceability matrix be a separate file or embedded in the plan artifact?]
