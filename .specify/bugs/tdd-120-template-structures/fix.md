# Bug Fix: zfa tdd plan consumes the zuraffa-1.0 template's declared structures

- **Slug**: tdd-120-template-structures
- **Fixed**: 2026-09-03
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/test-list.md, ./tdd/cycle-log.md (verification to follow in bug.test)

## Summary

`zfa tdd plan` now consumes all four declarative sections of the zuraffa-1.0
spec template, plan-side complete: Key Entities **tables** feed the existing
phase-0 entity pipeline (legacy bullets unchanged), the External Dependencies &
Contracts table and Layer Contracts section land in the plan artifact, an
undeclared-dependency lint catches spec contract violations at plan time, and a
strict Template Version gate pins the grammar (exit 3 on drift). Make-side
consumption (mock routing, signature-consistent generation) is deliberately
deferred to #909 and recorded as out of scope.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/services/spec_parser.dart` | modified | `SpecEntity.purpose`; table parsing in `parseKeyEntities` (mixed sections); `parseTemplateVersion` + `knownTemplateVersions`; `SpecDependency`/`LayerContract` models + `parseDependencies`/`parseLayerContracts`; `knownExternalDependencies` |
| `lib/src/plugins/tdd/commands/plan_command.dart` | modified | strict version gate (exit 3, `--> fix:`, before any parsing); artifact `## External dependencies` + `## Layer contracts` sections; undeclared-dependency lint (exit 2, `--> fix:`, no artifacts) |
| `lib/src/plugins/tdd/services/test_list_reader.dart` | modified | `readDependencies`/`readLayerContracts` (lenient, pre-919 artifacts → empty) |
| `test/plugins/tdd/bug_919_template_structures_test.dart` | added (suite adopted) | 14 CLI-level behaviors A1–A14 via `CliRunner` on temp projects |
| `test/plugins/tdd/services/bug_919_reader_test.dart` | added | reader round-trip for dependencies + layer contracts |
| `test/plugins/tdd/helpers/spec_fixture.dart` | added (pre-existing) | `writeSpec` (marker default), `writeRawSpec`, `kMinimalAcceptance`, `makeFeatureDir` |
| `test/plugins/tdd/bug_846_coverage_gate_test.dart`, `bug_830_widget_subject_kind_test.dart`, `commands/plan_persistence_marking_833_test.dart`, `commands/plan_gen_contract_test.dart` | modified | fixtures pin the Template Version marker (strict gate) / declare Hive (dependency lint) — assertions unchanged |

## Tests Added or Updated

- `bug_919_template_structures_test.dart::A1` — table entities with fields+purpose land in the artifact
- `::A2`/`::A10` — legacy bullet/no-entities regression (existing plan_gen_contract group covers; marker-adopted fixtures)
- `::A3` — phase-0 seam: `TestListReader.readEntities` returns table-planned entities (deliberate-mutant validated)
- `::A4`/`::A5`/`::A6` — version gate: missing/unknown → exit 3 + fix + no artifacts; `zuraffa-1.0` → proceeds (A6 mutant-validated)
- `::A7`/`::A8` — dependencies/layer contracts render row-for-row
- `::A9`/`::A12` — undeclared external → exit 2 naming it; no externals/declared-only → exit 0 (A12 mutant-validated)
- `::A13` — gate ordering: drift + coverage gap → exit 3
- `::A14` + `services/bug_919_reader_test.dart` — artifact round-trip through the new reader methods

## Local Verification

- Red evidence per behavior: `tdd/cycle-log.md` (cycles 1–7, commands + decisive output lines)
- Full scoped suite: `dart test test/plugins/tdd/` → 730 passed, 1 skipped, 0 failed (final run; one load flake observed and re-verified green)
- `dart analyze` on all touched files → no issues
- Deliberate-mutant checks: A3 (reader column shift), A6 (gate rejects known version), A12 (lint fires always) — all red under mutant, green restored

## Deviations from Assessment

- The seeded assessment (from issue #919 fetch) carried `[NEEDS CLARIFICATION]`
  placeholders; code paths were located during the fix (spec_parser.dart,
  plan_command.dart, test_list_reader.dart). Scope and gate semantics were
  decided with the user: **plan-side complete**, **strict version gate**
  (missing OR unknown marker = exit 3 on every spec, including legacy ones —
  legacy specs gain the marker to keep planning).
- A pre-existing uncommitted implementation of the table parsing (from an
  interrupted earlier session) was found in the working tree; it was reverted
  and rebuilt through the red-green loop to keep the evidence honest. Its
  speculative em-dash "bullet purpose" heuristic was deliberately not adopted
  (FR-002 requires legacy bullets unchanged).
- Artifact addition note: `## External dependencies` / `## Layer contracts`
  sections are placed after `## Key entities`; the header `## Key entities`
  gained an optional third `purpose` column only when an entity declares one
  (pre-919 artifacts read back byte-identically).

## Follow-ups

- #909 (mock-first make path; OPEN): consume `readDependencies`/`readLayerContracts`, signature-consistent interface generation.
- The strict version gate requires the marker on every repo spec that plans;
  `specs/*` in this repo and the repro project `~/zik_zak_test` need it before
  their next plan run.
- `verify_red_subdirectory_test.dart` (3 tests) times out under the harness's
  75s child cap when `dart bin/zfa.dart` cold JIT startup exceeds it (~1m36s
  measured this session) — environmental, reproduced on a clean tree, passed
  on the final suite run; if it recurs, the harness child timeout needs review.
- Concurrent-agent incident: another session forked empty branches
  (892/893/894) from this unmerged fix branch mid-work and one commit briefly
  landed on `894-corpus-economics`; it was moved back to
  `fix/tdd-120-template-structures`. Those branches fork from unpushed work —
  worth checking before they are built upon.