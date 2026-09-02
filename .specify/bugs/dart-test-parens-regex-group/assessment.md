# Bug Assessment: [zfa tdd verify-red/make] dart test -n <name> treats parens as regex group — blocks behaviors whose description has (sticky) or (FR-XXX)

- **Slug**: tdd-parens-regex
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/760
- **Verdict**: likely valid, needs reproduction
- **Severity**: medium

## Report (verbatim or summarized)

`zfa tdd verify-red` and `zfa tdd make` pass the test name directly to `dart test -n "<name>"` without escaping regex metacharacters. When the behavior description contains parentheses (e.g. `(sticky)`, `(idempotent)`, `(FR-XXX)`), `dart test -n` treats them as a regex group, causing either no match (exit 79) or unintended test selection. https://github.com/arrrrny/zuraffa/issues/760

## Symptom

`zfa tdd run` blocks on any behavior whose description contains `(...)` or other regex metacharacters. `dart test -n` reports "No tests match regular expression" (exit 79), and `verify-red` classifies as `runner-error`.

## Reproduction

1. `zfa tdd init` on a pure Dart package
2. `zfa tdd run <feature>` — succeeds for behaviors without parens (U1, U2)
3. Stops at U3: description ends with `(sticky)`
4. `dart test -n "U3 (FR-005, FR-006) ..."` → "No tests ran." exit 79
5. `verify-red` classifies as `runner-error`

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
