# Bug Assessment: [BUG] zfa tdd make subprocess killed (exit -9) for acceptance behaviors

- **Slug**: tdd-make-subprocess-killed
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/796
- **Verdict**: valid — confirmed with rebuilt zfa binary
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd make` for acceptance behaviors (A1-A9) fails with `generation-error` because the underlying `zfa make <id> --no-entity` subprocess gets killed (exit -9 = SIGKILL, likely OOM or timeout). Direct invocation of `zfa make a3 --no-entity` returns `❌ No active plugins to run.` but the TDD loop treats the exit as a crash. https://github.com/arrrrny/zuraffa/issues/796

## Symptom

`zfa tdd run` stops at A3:make with `generation-error` and `exit: -9`. A1/A2 make succeed (unexpressible → deferred), but A3 make crashes.

## Reproduction

1. `zfa setup --platforms=macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy any spec with acceptance behaviors (e.g. specs/004-dependency-injection/spec.md)
4. `zfa tdd plan 004-dependency-injection`
5. `zfa tdd run 004-dependency-injection` → exit 1, stops at A3:make

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed.]

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.
- Related to #758 (CRUD-keyword acceptance behaviors never reach green) — both are about `zfa tdd make` failing for acceptance behaviors.

## Open Questions

- [NEEDS CLARIFICATION: …]