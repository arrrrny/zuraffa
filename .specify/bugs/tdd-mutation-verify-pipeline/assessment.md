# Bug Assessment: mutation verify pipeline — fix preflight semantics + runnable at corpus scale

- **Slug**: tdd-mutation-verify-pipeline
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/837
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd verify` exits 64 with gate=preflight_red on a green suite — observed on every completed feature. The gate reads backwards for a post-green audit. Mutation never actually ran (`mutation_was_run: false`). The verify gate is broken: it rejects green suites and skips mutation testing entirely. https://github.com/arrrrny/zuraffa/issues/837

## Symptom

After a feature reaches green, `zfa tdd verify` exits 64 with gate=preflight_red. The gate logic is inverted — it should assert GREEN but reads as requiring RED. Mutation testing never executes (`mutation_was_run: false`). The verify step is unusable.

## Reproduction

1. Complete `zfa tdd run <feature>` — all behaviors green
2. Run `zfa tdd verify` → exit 64, gate=preflight_red
3. Check mutation output → `mutation_was_run: false`

## Suspected Code Paths

- The verify command's preflight gate logic — inverted or misconfigured
- The mutation test invocation — never actually triggered
- The threshold gate from .zfa.json — not read or applied

## Root Cause Hypothesis

High confidence: the verify preflight gate reads backwards (expects RED when it should expect GREEN), and the mutation test invocation is dead code or never reached. Two separate bugs: gate semantics + mutation not wired.

## Proposed Remediation

**Preferred**: (1) Fix preflight gate: assert suite GREEN + evidence complete (red+green per behavior). Red suite at verify time = hard fail. (2) Wire mutation test execution: scope to feature's subjects (namespaced per #827), bounded wall-clock, killed/survived/timed_out tallied. (3) Threshold gate from .zfa.json (default strict). (4) Survived mutants = exit 1 with per-mutant report + `--> fix:`. (5) Verify artifacts include spec-hash + subject-hash binding.

**Alternatives** (optional):
- Skip mutation testing entirely — loses the quality gate; not acceptable for 100% TDD claim.

**Files likely to change**:
- Verify command (gate logic fix)
- Mutation test invocation (wire it up)
- Verify artifacts (hash binding)
- .zfa.json schema (threshold config)

**Tests to add or update**:
- Green suite → verify passes (not exit 64)
- Red suite at verify time → hard fail
- Mutation actually runs (`mutation_was_run: true`)
- Survived mutants → exit 1 with report

## Risks & Considerations

- Mutation testing is slow — must be scoped to feature's subjects only
- Bounded wall-clock prevents runaway mutation runs
- Threshold must be configurable per project
- Depends on #827 (namespacing) for correct subject scoping

## Open Questions

- [NEEDS CLARIFICATION: What is the default mutation threshold (percentage of killed mutants)?]
- [NEEDS CLARIFICATION: Should mutation run inline or as a separate subprocess?]
