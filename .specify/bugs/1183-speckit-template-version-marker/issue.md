# Bug Issue: [TDD] specs authored by speckit-specify always exit 3 on first zfa tdd plan — Template Version marker missing

- **Slug**: 1183-speckit-template-version-marker
- **Issue**: 1183
- **State**: open
- **Severity**: medium
- **Author**: arrrrny
- **Labels**: bug, tdd

## Body

**Observed** (both feature runs this session): Specs written by `/speckit-specify`
(from the speckit template) carry no **Template Version** marker, so the FIRST
`zfa tdd plan` always fails:

```text
zfa tdd plan: contract drift — missing `**Template Version**` marker … (exit 3)
  --> fix: run `zfa tdd plan --migrate-spec` …
```

`--migrate-spec` fixes it in place (good UX), but the failure is 100%
deterministic for every new feature — the two pipelines disagree about the
authoring contract.

**Suggestion**: Either the speckit spec template ships the marker, or
speckit-specify injects it at authoring time (the same one-liner
`--migrate-spec` performs). First-plan-should-just-work.

**Related**: #990 (the marker machinery), observed on specs 077/078/079/080/081.

**Hard constraints**: fix the spec template or speckit-specify; one PR for the bug.
