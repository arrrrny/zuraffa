# Bug Fix: 1480 — zuraffa spec authoring grammar never reaches a spec-kit project

- **Slug**: 1480-spec-grammar-propagation
- **Fixed**: 2026-09-11T00:35:00Z
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/test-list.md, ./tdd/cycle-log.md, ./tdd/verification.md

## Summary

All three levers from the issue are implemented: (1) the spec↔contract mapping is decoupled from `spec.md` — `zfa tdd plan` now reads contract rows and FR traces from the feature's `contracts/*.md` files; (2) plan fails fast (exit 1, no artifacts, spec untouched) when any unit behavior would fallback-route, with `--allow-unit-fallback` as the migration escape hatch; (3) `zfa tdd init` propagates the zuraffa-1.0 authoring template into the project (install-on-absent, replace-grammarless, never touch a pinned template). Engine cycle, gen/make pipeline, and verify gate are untouched.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/services/spec_parser.dart` | modified | new `parseCriterionContractTraces`: FR-id-keyed `traces:` bindings for contracts files (same-line and #1319 continuation forms, fence-blanked, duplicate-FR refusal) |
| `lib/src/plugins/tdd/commands/plan_command.dart` | modified | `contracts/*.md` discovery + row merge (cross-source duplicate refusal); criterion→unit trace merge (double-declaration refusal, unknown-FR warning); `--allow-unit-fallback` flag; unit-fallback fail-fast gate (exit 1, `unit-fallback-refused`, persistence-marked behaviors exempt per #833/#1298) |
| `lib/src/cli/writers/tdd/spec_template_writer.dart` | added | `SpecTemplateWriter`: ensures `.specify/templates/spec-template.md` carries the zuraffa-1.0 grammar; embedded byte-exact template (`kZuraffaSpecTemplate`); created/replaced/already-current outcomes decided by the `**Template Version**` pin (#919 treaty) |
| `lib/src/plugins/tdd/commands/init_command.dart` | modified | wires the writer into `zfa tdd init` with loud created/REPLACED/already-current lines; failure is a misfire entry |
| `test/cli/writers/tdd/spec_template_writer_test.dart` | added | U3a-U3d writer contract + A3 `zfa tdd init` end-to-end |
| `test/plugins/tdd/commands/plan_contracts_decoupled_1480_test.dart` | added | U1+A1 declared routing via contracts file; U1b unknown-FR warning; U5a/U5b refusals |
| `test/plugins/tdd/commands/plan_unit_fallback_fail_fast_1480_test.dart` | added | A2 refusal + naming + no-artifacts + spec-untouched; A2b the three outs; U2b escape hatch; U2c traced green; U2d partial refusal |
| 21 legacy test files | modified | fixtures pre-dating the grammar: contract rows + traces added where the spec should be declared; `--allow-unit-fallback` where the labeled-fallback shape is the test's own subject |

## Diff Highlights

The gate (plan_command.dart, after the strict gate):

```
zfa tdd plan: unit-fallback-refused — 1 unit behavior(s) would route through
the legacy classifier fallback (spec: <path>).
  route: U1 -> unit lane [fallback: FR-001 carries no declared contract trace]
The unit lane can never self-heal: ...
  --> fix: add `traces: <Row>` under each FR above in spec.md, or declare the
      rows and the FR mapping in specs/<feature>/contracts/*.md ... or re-run
      with `--allow-unit-fallback`.
```

The decoupled mapping (contracts file):

```markdown
## Layer Contracts
**Function**:
- `TodoStore`: `add(Todo) -> bool`

## Contract Traces
- **FR-001**: traces: TodoStore.add
```

## Tests Added or Updated

- `spec_template_writer_test.dart::U3a-U3d/A3` — install/replace/preserve treaty + init end-to-end
- `plan_contracts_decoupled_1480_test.dart::U1+A1/U1b/U5a/U5b` — declared routing from contracts/*.md; warning and refusal edges
- `plan_unit_fallback_fail_fast_1480_test.dart::A2/A2b/U2b/U2c/U2d` — fail-fast gate + escape hatch + unaffected contracts
- legacy suites: fixtures updated to the new plan contract (see Changes table)

## Local Verification

- Commands run: `dart test test/cli/writers/tdd/spec_template_writer_test.dart test/plugins/tdd/commands/plan_contracts_decoupled_1480_test.dart test/plugins/tdd/commands/plan_unit_fallback_fail_fast_1480_test.dart` → 14/14 pass
- Commands run: `dart test test/plugins/tdd/services/ -j 2` → 804/804 pass; chunked re-runs of every plan-adjacent legacy suite (commands/ 64 files, root-level plan consumers) → all pass after fixture triage
- Commands run: `dart analyze <changed files>` → No issues found; `dart format` → 0 remaining diffs on changed files (two PRE-EXISTING unformatted files on master reverted out of scope)
- Real CLI end-to-end (issue's REQUIRED checks): `zfa tdd init` on a fresh spec-kit-shaped project installs the grammar template (`## Layer Contracts`=1, `traces:`=4, `zuraffa-1.0` pin present); `zfa tdd plan` on the all-fallback spec exits **1** in seconds naming `U1 (FR-001)`; adding `contracts/todo-seam.md` with the row + criterion trace flips the same spec to **exit 0** with `route: U1 -> unit lane (func surface) [declared: contract row: TodoStore]`
- Manual checks: refused plan leaves spec.md byte-identical (no marker emission) and writes no artifacts — asserted by A2

## Deviations from Assessment

- The fail-fast gate EXEMPTS persistence-marked behaviors (`[persistent]` tag or storage-row trace): they take the harness-backed test path (#833/#1298), which is not the dead-end the issue describes. Discovered during triage when the pre-existing `persistence_declaration_test.dart` storage-trace contract (exit 0 today) collided with the gate; exemption recorded in code comments and covered by the unchanged 071/833 suites.
- Legacy-fixture triage touched 21 test files (more than the assessment's estimate): the corpus encodes the pre-#1480 contract extensively. Fixture updates follow two rules only — grammar-complete fixtures where the spec should be declared; `--allow-unit-fallback` where the labeled-fallback shape is the test's own subject.

## Follow-ups

- Companion issues #1417 (boundary scripts) and #1466 (plan exit 0 on all-fallback specs) remain open — #1466's core is largely addressed by the fail-fast gate for the unit lane; the acceptance lane's marker migration still exits 0 by design.
- Consider a template-drift guard tying `kZuraffaSpecTemplate` to the repo-local `.specify/templates/spec-template.md` (the #1183 drift family).
- The `contract:` lane (open issue #1419) may want the same contracts/*.md sourcing.
