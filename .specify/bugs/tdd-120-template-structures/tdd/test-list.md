---
feature: tdd-120-template-structures
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 12
planned_at: 79169b56
updated_at: 79169b56
suite_baseline: green
---

# Test List: zfa tdd plan consumes the zuraffa-1.0 template's declared structures

Bug fix for issue #919 ([TDD-120]). Scope agreed with the user: **plan-side
complete** — parsing, gating, and artifact rendering land here; make-side
consumption (mock routing, signature-consistent generation) is #909 territory.

Test level: behaviors marked `cli` drive the real entry point in-process
(`CliRunner.runCapturing(['tdd', 'plan', ...])` on a temp project — the same
harness as `bug_846_coverage_gate_test.dart`). Behaviors marked `integration`
additionally consume the produced artifact through `TestListReader` (the
boundary #909 will consume from). No subprocess spawning needed.

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`. All kind `example`.

| id  | behavior                                                                                                                                | traces      | kind | state   | test |
| --- | -------------------------------------------------------------------------------------------------------------------------------------- | ----------- | ---- | ------- | ---- |
| A1  | A `## Key Entities` markdown table row `\| ShoeSizePreference \| `id: String`, `sizeEu: double` \| purpose \|` yields the entity with fields `id:String`,`sizeEu:double` and its purpose in the plan artifact's Key entities table | FR-001 | example | PENDING | |
| A2  | A legacy bullet-format Key Entities section (with the Template Version marker present) extracts entities identically to today — no regression | FR-002 | example | DONE | `test/plugins/tdd/commands/plan_gen_contract_test.dart` (bug 829 group; fixture gains the marker — see cycle log) |
| A3  | Entities planned from a table are read back by the phase-0 path: `TestListReader.readEntities` returns name + fields from the produced artifact | FR-001 | example | PENDING | |
| A4  | A spec missing the `**Template Version**` marker makes `zfa tdd plan` exit 3, print a `--> fix:` line pointing at the zuraffa extension template, and write no artifacts | FR-003, FR-006 | example | PENDING | |
| A5  | A spec carrying an unknown version (`zuraffa-2.0`) makes plan exit 3 naming the offending version, with `--> fix:` line, writing no artifacts | FR-003, FR-006 | example | PENDING | |
| A6  | A spec carrying `**Template Version**: `zuraffa-1.0`` plans successfully (exit 0, artifacts written) | FR-003 | example | PENDING | |
| A7  | An External Dependencies & Contracts table (`\| Dependency \| Type \| Contract \| Mock Priority \|`) lands row-for-row (dependency, type, contract, mock priority) in the plan artifact | FR-004, FR-008 | example | PENDING | |
| A8  | A Layer Contracts section (bold layer line + backticked `Interface`: signatures bullets) lands per-layer, per-interface, with method signatures in the plan artifact | FR-005, FR-008 | example | PENDING | |
| A9  | A requirement statement referencing a known external dependency (e.g. `Hive`) not declared in the dependencies table makes plan exit 2 naming the dependency, with a `--> fix:` line, writing no artifacts | FR-007 | example | PENDING | |
| A10 | A spec with no Key Entities section plans cleanly and writes no entities section (as today) | FR-001 | example | DONE | `test/plugins/tdd/commands/plan_gen_contract_test.dart:261` (fixture gains the marker) |
| A11 | A Key Entities section mixing a table and legacy bullets extracts entities from both forms | FR-001, FR-002 | example | PENDING | |
| A12 | A spec whose requirements reference no externals — or only declared ones — plans without the dependency lint firing (exit 0) | FR-007 | example | PENDING | |
| A13 | A spec with BOTH a missing Template Version and a coverage gap exits 3, not 2 — the version gate runs before the coverage gate | FR-006 | example | PENDING | |
| A14 | Dependencies and layer contracts are read back by `TestListReader` from the produced artifact (new `readDependencies`/`readLayerContracts`) | FR-009 | example | PENDING | |

## Inner loop: unit behaviors

Not derived — this list was planned `outer-only` (bug workflow, no `plan.md`).
The FR-001..FR-009 requirements are exercised through the acceptance behaviors
above at the CLI artifact boundary; the acceptance runner is the repo's
`dart test` CLI harness.

## Invariants and edge cases still to place

- None unplaced. The parser-level unit behaviors (regex boundaries, invalid
  identifier rejection in table column 1) are pinned indirectly by A1/A11 and
  by the existing `spec_parser_test.dart` bullet-format suite, which stays
  green throughout.

## Out of scope

- Make-side consumption of declared dependencies (`zfa tdd make` routing to
  `zfa mock create`): #909 (mock-first make path), still OPEN.
- Generated repository/datasource interfaces matching declared Layer Contract
  signatures (incl. exit 2 on an unexpressible declared method): #909 lineage;
  this fix only lands the declarations in the plan artifact.
- Phase-0 entity creation behavior itself: already implemented and tested
  (bug #829 lineage, `run_command_test.dart`); this fix only ensures
  table-declared entities reach that existing path (A3).

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md` at planning time:

- Single test: `dart test <file> --plain-name "<name>"`
- Whole file: `dart test <file>`
- Full suite (feature scope): `dart test test/plugins/tdd/`
- Static analysis (feature scope): `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/`
