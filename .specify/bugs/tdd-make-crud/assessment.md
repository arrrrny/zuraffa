# Bug Assessment: tdd make: CRUD-keyword acceptance behaviors cannot reach green — make ends with generation-error (subject never implemented)

- **Slug**: tdd-make-crud
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/758
- **Verdict**: likely valid, needs reproduction
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd make <acceptance-id>` (CRUD-keyword acceptance path) reaches the CRUD branch of `GenerationPlanner.plan()` but never implements the acceptance subject. The plan succeeds, but `lib/tdd/<id>_subject.dart` still throws `UnimplementedError`, so the post-generation target run stays red and `make` stops with `generation-error`. The loop is blocked for natural spec phrasing containing CRUD keywords. https://github.com/arrrrny/zuraffa/issues/758

## Symptom

Acceptance behaviors with CRUD-keyword Then-clauses (e.g. "the Todo repository service persists a todo item") end with `generation-error` because the subject is never implemented, even though the plan's pipeline steps succeed.

## Reproduction

1. Create a spec with an acceptance behavior whose Then-clause mentions CRUD keywords (repository, service, use case, crud).
2. Run `zfa tdd gen A1 && zfa tdd verify-red A1 && zfa tdd make A1`.
3. Observe `make: behavior=A1 outcome=generation-error` — subject file still throws `UnimplementedError`.

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed.]

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.

## Open Questions

- [NEEDS CLARIFICATION: …]
