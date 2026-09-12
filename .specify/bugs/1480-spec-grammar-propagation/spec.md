**Template Version**: `zuraffa-1.0`

# Bug Spec: 1480 — spec grammar propagation and contract decoupling

**Input**: GitHub issue #1480 — zuraffa spec authoring grammar never reaches a spec-kit project; the installed spec-template.md has no Layer Contracts/traces: grammar and no zfa verb installs zuraffa's own template.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `zfa tdd plan` MUST read the spec↔contract mapping from the feature's
  `contracts/*.md` files when they exist: contract rows declared in those files
  participate in declared routing exactly like rows declared in `spec.md`, so a
  spec-kit-authored spec without inline zuraffa grammar resolves its unit lane.
            traces: PlanCommand, SpecParser
- **FR-002**: `zfa tdd plan` MUST refuse (exit 1, no artifacts, spec untouched) when any
  unit behavior would fallback-route through the legacy description classifier,
  naming every offending behavior and its FR; `--allow-unit-fallback` restores the
  legacy labeled-fallback behavior as the migration escape hatch.
            traces: PlanCommand
- **FR-003**: `zfa tdd init` MUST ensure `.specify/templates/spec-template.md` carries the
  zuraffa-1.0 authoring grammar: install when absent, replace a grammarless stock
  spec-kit template, and never touch a template that already pins a known zuraffa
  template version.
            traces: SpecTemplateWriter, InitCommand
- **FR-004**: A criterion-keyed trace in a contracts file naming an FR the spec does not
  declare MUST warn (parity with the #1319 unbound-trace warning) and never refuse.
            traces: SpecParser
- **FR-005**: A contract row name declared in both `spec.md` and a contracts file, or an FR
  traced from both sources, MUST refuse naming both sources — never a silent win.
            traces: PlanCommand

## Layer Contracts

**Function**:
- `SpecTemplateWriter`: `write(String) -> Future<String?>`
- `SpecParser`: `parseCriterionContractTraces(String) -> Map<String, List<String>>`

### Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| ContractRowDecl | `name: String`, `kind: ContractRowKind`, `specLine: int` | A declared row an FR can trace to, from spec.md or contracts/*.md |
| CriterionTrace | `frId: String`, `tokens: List<String>` | An FR↔contract-row mapping held beside the spec |

## Acceptance Scenarios

1. **Given** a spec-kit-authored spec with no zuraffa grammar sections and a
   contracts file declaring rows and criterion traces **When** `zfa tdd plan` runs
   **Then** the unit behaviors route `[declared: contract row: …]` and the plan exits 0.
   **Type**: acceptance
2. **Given** a spec whose FRs carry no traces and no contracts files exist **When**
   `zfa tdd plan` runs **Then** the plan refuses with exit 1 naming each `U<n> (FR-xxx)`
   and writes no artifacts.
   **Type**: acceptance
3. **Given** a project whose `.specify/templates/spec-template.md` is the stock
   spec-kit template **When** `zfa tdd init` runs **Then** the template carries the
   zuraffa-1.0 grammar (`## Layer Contracts`, `traces:`, the version marker).
   **Type**: acceptance
