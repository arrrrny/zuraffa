## Summary

`zfa tdd plan` now consumes the zuraffa-1.0 spec template's declarative
sections (issue #919, plan-side complete):

1. **Key Entities table** (`| Entity | Fields | Purpose |`) is parsed into
   the plan artifact's Key entities section (third `purpose` column when any
   entity declares one) and feeds the existing phase-0 entity pipeline via
   `TestListReader.readEntities` — legacy bullet format unchanged, mixed
   sections supported.
2. **External Dependencies & Contracts table** lands row-for-row in a new
   `## External dependencies` artifact section.
3. **Layer Contracts** land per-layer (`### <layer>` blocks with backticked
   interface declarations) in a new `## Layer contracts` section.
4. **Template Version pin**: missing or unknown `**Template Version**` marker
   = exit 3 with a `--> fix:` line, before any parsing, no artifacts
   (contract drift). Known: `zuraffa-1.0`.
5. **Undeclared-dependency lint**: a requirement statement referencing a
   known external (Hive, SharedPreferences, Firebase, Supabase, SQLite,
   Drift) not declared in the dependencies table = exit 2 naming the
   dependency with a `--> fix:` line.
6. `TestListReader.readDependencies`/`readLayerContracts` round-trip the new
   sections so the mock-first make path (#909) can consume them.

Rationale for the strict version gate (missing marker = exit 3 on every spec,
including legacy ones): spec grammar is a contract; an unpinned spec must not
drive a silently-wrong plan. Legacy specs gain the marker to keep planning —
the four existing plan-test fixture files were updated accordingly
(assertions unchanged).

## Changes

| File | Change |
|------|--------|
| `lib/src/plugins/tdd/services/spec_parser.dart` | table Key Entities (+`purpose`), `parseTemplateVersion`/`knownTemplateVersions`, `SpecDependency`/`LayerContract` + parsers, `knownExternalDependencies` |
| `lib/src/plugins/tdd/commands/plan_command.dart` | strict version gate (exit 3), `## External dependencies` + `## Layer contracts` artifact sections, undeclared-dependency lint (exit 2) |
| `lib/src/plugins/tdd/services/test_list_reader.dart` | `readDependencies`/`readLayerContracts` (lenient; pre-919 artifacts → empty) |
| `test/plugins/tdd/bug_919_template_structures_test.dart` | new — 14 CLI-level behaviors A1–A14 |
| `test/plugins/tdd/services/bug_919_reader_test.dart` | new — reader round-trip |
| `test/plugins/tdd/helpers/spec_fixture.dart` | new — shared fixture helpers (marker-aware `writeSpec`) |
| 4 existing plan-test fixture files | marker / declared-dependency fixture updates only (assertions unchanged) |

## Verification

- TDD loop: 14/14 behaviors closed with recorded red-green evidence
  (`tdd/cycle-log.md`), 4 deliberate mutants caught (A1, A3, A6, A12).
- `dart test test/plugins/tdd/` → **731 passed, 1 skipped, 0 failed**.
- `dart analyze` on touched files → no issues.
- Audit: `tdd/verification.md` → **PASS_WITH_GAPS** (9 PROVEN, 5
  control/characterization, 0 HIGH smells, 12/12 criteria covered).
- Bug verification: `.specify/bugs/tdd-120-template-structures/test.md` → **verified**.

Deferred to #909 (recorded out of scope): make-side mock routing and
signature-consistent interface generation.

Assessment: `.specify/bugs/tdd-120-template-structures/assessment.md`

Closes #919.