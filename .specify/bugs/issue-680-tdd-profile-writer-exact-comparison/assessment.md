# Bug Assessment: [zfa tdd init] TddProfileWriter rejects valid non-Flutter profiles on re-run (exact-content comparison too strict)

- **Slug**: issue-680-tdd-profile-writer-exact-comparison
- **Created**: 2026-09-01T14:12:00Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/680
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

`TddProfileWriter` (used by `zfa tdd init`) throws `StateError` and exits non-zero when an existing `tdd-profile.md` has valid-but-different content — even when the project kind (Dart vs Flutter) matches exactly. This blocks idempotent re-runs of `zfa tdd init` on any project that already has a profile.

See: https://github.com/arrrrny/zuraffa/issues/680

## Symptom

When running `zfa tdd init` on a project that already has a `tdd-profile.md` with valid-but-different content (e.g. enriched by an ecosystem detector), the tool throws `StateError: tdd-profile.md already exists at ... with different content; refusing to overwrite.` and exits non-zero, even though the profile's runner kind matches the current project.

## Reproduction

1. `zfa tdd init` on a pure Dart package (creates `tdd-profile.md`)
2. Enrich the profile with richer metadata (e.g. ecosystem detector adds `stacks: dart: { runner: "package:test (^1.24.0)", ... }`)
3. Run `zfa tdd init` again
4. → `StateError` thrown; non-zero exit

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed.]

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.
- The issue author also identified a secondary bug in the frontmatter regex (`multiLine: true` vs `dotAll: true`) that should be verified separately.

## Open Questions

- [NEEDS CLARIFICATION: Is the exact-content comparison in `TddProfileWriter.write()` actually the gate, or does the error originate elsewhere?]
- [NEEDS CLARIFICATION: Does the `multiLine: true` frontmatter regex bug actually break the attempted fix, or is it a separate issue?]
- [NEEDS CLARIFICATION: What is the `isFlutterProfile` logic and how does it determine Dart vs Flutter?]
