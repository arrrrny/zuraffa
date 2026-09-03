# Bug Assessment: [TDD-120] zfa parses the zuraffa template's declared structures (Key Entities table, Dependencies & Contracts, Layer Contracts, Template Version pin)

- **Slug**: tdd-120-template-structures
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/919
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

The zuraffa-1.0 spec template declares structures zfa must consume, but `zfa tdd plan` only parses the core spec-kit sections; the template's declarative sections are invisible. Four work items:

1. **Key Entities table** → phase-0 `zfa entity create` (extractor currently expects legacy bullet format, ignores the table; phase-0 entity creation silently never happens).
2. **External Dependencies & Contracts table** → input for the mock-first make path (#909); today parsed by nothing. Undeclared-dependency lint = exit 2.
3. **Layer Contracts** → generated repository/datasource interfaces must match declared signatures; unexpressible declared method = exit 2 naming it.
4. **Template Version pin** (`zuraffa-1.0`) → unknown/missing version = exit 3 (contract drift) with `--> fix:` line.

Full detail: https://github.com/arrrrny/zuraffa/issues/919

## Symptom

On a spec authored from the zuraffa-1.0 template, `zfa tdd plan`/`zfa tdd run` skip phase-0 entity creation entirely (Key Entities table ignored), and the declared dependencies/layer contracts never reach the make/mock path — unit behaviors route to func-stubs with no entity.

## Reproduction

1. Use the repro project `~/zik_zak_test`, spec `001-shoe-size-tracker` (authored from the zuraffa template; path `~/zik_zak_test/specs/001-shoe-size-tracker/spec.md`).
2. Run `zfa tdd plan` — observe that the Key Entities table (ShoeSizePreference row) is not extracted; no phase-0 entity creation is announced.
3. Run `zfa tdd run` — behaviors drive with no ShoeSizePreference entity; unit behaviors route to func-stubs.
4. (Work item 4) Remove the `**Template Version**: `zuraffa-1.0`` line → currently no exit-3 contract-drift error.

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually. Likely: the spec parser / entity extractor in the tdd plan pipeline (`zfa tdd plan`), wherever the legacy bullet-format `- **Name**: description` entity extraction lives, plus the plan-artifact writer consumed by `zfa tdd make` / `zfa mock create`.]

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed. Working assumption: the tdd-plan parser only implements the legacy bullet grammar for entities and has no parsers at all for the zuraffa-1.0 Key Entities table, Dependencies & Contracts table, Layer Contracts section, or Template Version marker.]

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix. Per the issue: table-format entity extraction feeding the existing phase-0 path; dependencies/layer-contracts extraction into the plan artifact; Template Version gate with exit 3 on drift; exit 2 lints for undeclared dependencies and unexpressible declared methods.]

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.
- Four distinct work items in one issue — likely needs decomposition or ordered delivery (item 2 depends on #909's mock path).
- Repro project lives outside this repo (`~/zik_zak_test`) — verification requires that path to exist locally.
- Both entity formats (legacy bullet + zuraffa-1.0 table) must stay supported — regression risk for legacy specs.

## Open Questions

- [NEEDS CLARIFICATION: should this land as one PR or be split per work item?]
- [NEEDS CLARIFICATION: where do parsed dependencies/layer contracts persist — feature's tdd/ dir or the registry?]
- [NEEDS CLARIFICATION: is #909 (mock-first make) already merged enough for work item 2's consumption path?]
