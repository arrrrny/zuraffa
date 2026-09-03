# Bug Assessment: zfa parses the zuraffa template's declared structures

- **Slug**: zuraffa-template-structures
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/919
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> Part of #908. The zuraffa spec template (`zuraffa-1.0`, shipped in speckit-extensions/zuraffa) is now the owned contract. Verified live: `zfa tdd plan` parses core sections (Given/When/Then ACs → acceptance behaviors, FR-xxx → unit behaviors, persistence-kind tagging) but the template's NEW declarative sections — Key Entities table, External Dependencies & Contracts table, Layer Contracts, Template Version pin — are invisible to zfa.
>
> Four work items:
> 1. Parse Key Entities table → phase-0 entity create (table format: `| Entity | Fields | Purpose |`)
> 2. Parse External Dependencies & Contracts table → mock-first input for #909
> 3. Parse Layer Contracts → interface generation targets
> 4. Verify Template Version → treaty pin (unknown/missing = exit 3)

## Symptom

`zfa tdd plan` on a spec authored with the zuraffa-1.0 template produces a test list but ignores four declarative sections that the template declares: (1) the Key Entities table is not extracted → no phase-0 entity creation → `zfa tdd run` drives behaviors with no entities, (2) the Dependencies table is not parsed → no mock-first make path input, (3) Layer Contracts are not read → generated interfaces may not match declared signatures, (4) the Template Version marker is not validated → a non-zuraffa or outdated spec is silently processed with wrong grammar assumptions.

## Reproduction

1. Create a spec using the zuraffa-1.0 template with a Key Entities table:
   ```markdown
   | Entity | Fields | Purpose |
   |--------|--------|---------|
   | ShoeSizePreference | `id: String`, `sizeEu: double` | One saved shoe size |
   ```
2. Run `zfa tdd plan <feature>` — the test list is generated but no entity table is in the plan artifact; phase-0 entity creation does not happen.
3. Check the plan output — no mention of `ShoeSizePreference` as an entity to be created.
4. Remove the `**Template Version**: \`zuraffa-1.0\`` line from the spec → `zfa tdd plan` still succeeds (should exit 3).

## Suspected Code Paths

- `lib/src/plugins/tdd/services/spec_parser.dart:88-100` — `SpecParser` already has `_entityTableHeader` regex (line 93) and `_entityTableRow` regex (line 99) for the zuraffa-1.0 table format, plus `_entityBullet` (line 80) for legacy bullet format. The `SpecEntity` class (line 31) has a `purpose` field for the table's third column. This suggests partial implementation exists.
- `lib/src/plugins/tdd/services/spec_parser.dart:46-100` — The parser already parses Key Entities from both bullets and tables per the regex definitions. But the PLAN COMMAND must use the parsed entities for phase-0.
- `lib/src/plugins/tdd/commands/plan_command.dart:70-95` — The plan command already validates Template Version (line 76-95): it calls `SpecParser().parseTemplateVersion(specMd)` and exits 3 on missing/unknown. This part IS implemented.
- `lib/src/plugins/tdd/commands/plan_command.dart:97-100` — Calls `SpecParser().parse(feature, specMd)` to get behaviors.
- `lib/src/plugins/tdd/services/entity_lookup.dart:39-52` — `locateEntityFile` checks if an entity file exists at the canonical path; used by phase-0 of the run driver.
- `lib/src/plugins/tdd/commands/run_command.dart` — the run driver's phase-0 (not fully visible but referenced in comments)
- `test/plugins/tdd/bug_919_template_structures_test.dart:1-80` — existing tests for bug #919, testing A1 (table-declared entities in plan artifact)

## Root Cause Hypothesis

**High confidence.** Based on the code evidence:
- **Template Version (Work item 4)**: Already implemented — `plan_command.dart:70-95` validates the template version and exits 3 on drift. The `SpecParser` has `knownTemplateVersions` and `parseTemplateVersion`.
- **Key Entities table (Work item 1)**: Partially implemented — `SpecParser` has the regex patterns for table parsing and `SpecEntity` has the `purpose` field. The test `bug_919_template_structures_test.dart` verifies that table-declared entities appear in the plan artifact. But the plan command may not yet emit the entities in a format that the run driver's phase-0 can consume for entity creation.
- **Dependencies table (Work item 2)**: Not implemented — there is no regex or parser for the Dependencies & Contracts table in `spec_parser.dart`. No `mock create` routing exists in the generation planner.
- **Layer Contracts (Work item 3)**: Not implemented — no parsing of the `**Domain**:` layer contracts section exists.

The gap is that the parser reads entities but the plan→run pipeline does not yet use them for phase-0 entity creation, and the Dependencies/Layer Contracts tables are not parsed at all.

## Proposed Remediation

**Preferred**:
1. **Complete Key Entities → phase-0**: Ensure the plan artifact includes a `phase-0: entities` section that the run driver reads and uses to run `zfa entity create -n <Name> --field <n>:<T> ...` for each row. The parser already extracts entities from tables — wire the extraction to the run driver.
2. **Parse Dependencies table**: Add regex patterns in `SpecParser` for the Dependencies & Contracts table. Store the parsed dependencies in the plan artifact. Wire to `zfa mock create` via the generation planner (blocked on #909).
3. **Parse Layer Contracts**: Add parsing for `**Domain**:` and similar layer contract sections. Store in the plan artifact. Wire to `zfa make` so generated interfaces match declared signatures.
4. **Template Version**: Already implemented — verify with the existing test.

**Alternatives**:
- **Table-only parsing**: Only support the zuraffa-1.0 table format, not the legacy bullet format — simpler but breaks backward compatibility.
- **Lazy entity creation**: Defer entity creation to `zfa tdd make` instead of phase-0 — keeps the run driver simpler but means behaviors may reference entities that don't exist yet.

**Files likely to change**:
- `lib/src/plugins/tdd/services/spec_parser.dart` — add Dependencies and Layer Contracts parsing
- `lib/src/plugins/tdd/commands/plan_command.dart` — emit phase-0 entities in plan artifact
- `lib/src/plugins/tdd/commands/run_command.dart` — consume phase-0 entities for entity creation
- `lib/src/plugins/tdd/services/generation_planner.dart` — route declared dependencies to mock-create

**Tests to add or update**:
- Already exists: `test/plugins/tdd/bug_919_template_structures_test.dart` — A1-A14 behaviors
- Add: Dependencies table parsing test
- Add: Layer Contracts parsing test
- Add: Phase-0 entity creation test (entities from table → `zfa entity create` invoked)
- Add: Template Version exit 3 test (already covered by plan command)

## Risks & Considerations

- **Both formats must be supported**: Legacy specs use bullet format; zuraffa-1.0 uses table format. The parser must handle both, with the table format adding `purpose` metadata.
- **Generation planner routing**: The Dependencies table → mock-create path requires #909 to land first. Without #909, parsed dependencies would have no consumer.
- **Layer Contracts verification**: Generated interfaces matching declared signatures requires a post-generation comparison step — the generator may not express all declared signatures (the #829 honesty rule: unexpressible = exit 2).

## Open Questions

- [NEEDS CLARIFICATION: Is the plan command's entity extraction already writing entities to the plan artifact, or only parsing them internally without persisting?]
- [NEEDS CLARIFICATION: Does the run driver's phase-0 already read entities from the plan artifact, or is phase-0 still hardcoded?]
- [NEEDS CLARIFICATION: The test `bug_919_template_structures_test.dart` tests A1-A14 — are all 14 behaviors green, or are some still failing?]
