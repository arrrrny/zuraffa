# Feature Specification: FR manual exemption — route inherently non-unit FRs out of the unit behaviour lane

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `feat/1484-fr-manual-exemption`

**Created**: 2026-09-11

**Status**: Draft

**Input**: Issue #1484 — `zfa tdd plan`: no way to declare an FR as not-a-unit-behaviour; inherently non-unit FRs derive mandatory unit rows that can never pass `make`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Explicit FR manual exemption (Priority: P1)

An author of a zuraffa-1.0 spec has functional requirements that are inherently non-unit — UI appearance ("visually distinguish completed tasks"), negative whole-app properties ("MUST NOT transmit task data anywhere"), reactivity, presentation text. Today every FR unconditionally derives a unit behaviour row (`spec_parser.dart` `_extractUnit`), the row can never honestly pass `make`, and `zfa tdd run` dead-ends with no opt-out. The author needs a declaration, mirroring the acceptance-side `**Type**:` marker that already exists for scenarios (#846 gave acceptance criteria the `(manual:)` escape hatch), that routes an FR to a manual declaration instead of a unit behaviour row.

**Why this priority**: Without the explicit opt-out the run loop is permanently blocked for any spec containing an inherently non-unit FR — the single largest dead-end class reported against `zfa tdd run`.

**Independent Test**: Plan a spec whose FR-010 carries a `**Type**: manual` continuation line; assert the plan exits 0, emits no `U` row for FR-010, and records FR-010 under the traceability matrix's manual section with its full text.

**Acceptance Scenarios**:

1. **Given** a zuraffa-1.0 spec whose FR block contains a `**Type**: manual` continuation line, **When** `zfa tdd plan` runs, **Then** that FR derives no unit behaviour row and the plan exits 0
   **Type**: acceptance

2. **Given** an FR declared `**Type**: manual`, **When** the traceability matrix renders, **Then** the FR appears with its full text under a `manual:` section tagged `manual` — tracked, not hidden
   **Type**: acceptance

3. **Given** a spec mixing a manual FR with a `traces:`-bound FR, **When** the document-wide unit ids are assigned, **Then** the manual FR consumes its unit id (alignment preserved) and the traced FR's id is unchanged
   **Type**: acceptance

---

### User Story 2 - Default-to-manual for unbindable FRs (Priority: P1)

An FR with no `traces:` binding and no `**Type**:` marker has no declared contract to derive an honest unit subject from — today plan silently routes it through the legacy fallback classifier into a unit row that can never pass `make` (the #1308 vacuous-green dead-end class). The default must flip: an unbindable FR is a manual declaration by default, collapsing the entire fallback-routing dead-end class.

**Why this priority**: This is the change that removes the class — without it every legacy untraced FR keeps manufacturing doomed unit rows.

**Independent Test**: Plan a spec with an untraced, unmarked FR; assert the FR produces no unit row, the plan exits 0, and a warning naming the FR and both remedies is printed.

**Acceptance Scenarios**:

1. **Given** an FR with no `traces:` binding and no `**Type**:` marker, **When** `zfa tdd plan` runs, **Then** the FR defaults to a manual declaration rather than a unit behaviour row
   **Type**: acceptance

2. **Given** such an unmarked, unbound FR, **When** plan runs, **Then** plan emits a warning naming the FR and the two remedies: (a) add a contract trace, or (b) declare `**Type**: manual`
   **Type**: acceptance

3. **Given** an FR whose block binds a `traces:` line to declared contract rows, **When** `zfa tdd plan` runs, **Then** the FR still derives its unit behaviour row exactly as before (backwards compatible)
   **Type**: acceptance

---

### User Story 3 - Coverage accounting stays honest (Priority: P2)

The coverage gate (#846) must keep proving every requirement statement is accounted for. FRs routed manual count toward coverage as manual declarations — not as missing behaviours and not as silent gaps. The machine block of `tdd/traceability.md` carries the counts; verify/corpus drift checks are unaffected.

**Why this priority**: Without coherent gate accounting the default-to-manual flip would turn every untraced FR into an exit-2 gap — worse than the bug being fixed.

**Independent Test**: Plan a spec with one traced FR and one defaulted FR; assert exit 0, the matrix's machine block counts both statements, and the manual count includes the defaulted FR.

**Acceptance Scenarios**:

1. **Given** a spec whose FRs are a mix of traced and manual, **When** the coverage gate evaluates, **Then** no gap is reported for manual FRs and the gate passes
   **Type**: acceptance

2. **Given** the rendered `traceability.md`, **When** the machine block is read, **Then** `manual:` counts the FR manual declarations alongside acceptance-side `(manual:)` criteria and `open-gaps` stays 0
   **Type**: acceptance

3. **Given** an existing feature spec where every FR carries a `traces:` binding, **When** `zfa tdd plan` re-plans it, **Then** the derived behaviour rows are byte-identical to the pre-1484 plan (backwards compatible, marker is opt-in)
   **Type**: acceptance

---

### Edge Cases

- What happens when an FR carries BOTH a `**Type**: manual` marker and a `traces:` line? (the explicit declaration outranks the trace — the FR routes manual)
- What happens when a `**Type**: manual` line appears inside a fenced code block example? (it is documentation, not a declaration — ignored, mirroring the scenario-marker walk)
- What happens when an FR-table row (`| FR-001 | ... |`) carries the marker as a continuation line? (the block walk handles bullet and table grammars identically)
- What happens when an FR's `traces:` line binds nothing (all tokens dropped)? (the FR is unbound → defaults to manual; the existing #1319 unbound-trace warning also fires)
- What happens when the manual FR is the LAST requirement? (it consumes its unit id; no rows shift)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The spec parser MUST recognize a `**Type**: manual` continuation line inside an FR block (bullet or FR-table grammar) as the FR's manual exemption declaration, mirroring the acceptance-side `**Type**:` marker pattern used for scenarios
- **FR-002**: The parser MUST NOT derive a unit behaviour row for an FR declared `**Type**: manual`; the FR MUST still consume its document-wide unit id so trace-walk alignment is preserved
- **FR-003**: The parser MUST route an FR with no `traces:` binding and no `**Type**:` marker to a manual declaration by default instead of deriving a unit behaviour row
- **FR-004**: `zfa tdd plan` MUST emit a warning naming any FR that defaults to manual (no marker, no binding) and stating the two remedies: add a contract trace, or declare `**Type**: manual`
- **FR-005**: `tdd/traceability.md` MUST list manually-declared FRs under a `manual:` section with their full text and a `manual:` tag, and mark them `manual` in the main matrix table
- **FR-006**: The coverage gate MUST count manually-declared FRs toward coverage as manual declarations, never as missing behaviours
- **FR-007**: An FR whose block carries a `traces:` line binding declared contract rows MUST continue to derive its unit behaviour row unchanged
- **FR-008**: The `zfa tdd run`, `zfa tdd gen`, `zfa tdd make`, and `zfa tdd verify` commands MUST NOT change: manually-declared FRs never produce a unit row, so the loop never sees one

## Layer Contracts

**Domain**:
- `SpecParser.parseFrRoutings`: `parseFrRoutings(specMd) -> List<FrRouting>`

### Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| FrRouting | `frId: String`, `unitId: String`, `specLine: int`, `manualMarker: bool`, `traceTokens: List<String>`, `rawText: String` | One FR's declaration-level routing facts: whether it declares manual, what its block binds, and which unit id it consumes |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An FR declared `**Type**: manual` produces zero unit rows in `zfa tdd plan` output — measured by planning a fixture spec and asserting the test list contains no row for that FR while the traced sibling keeps its row and id
- **SC-002**: An untraced, unmarked FR produces a warning naming the FR and both remedies, and zero unit rows — measured on a fixture spec with exit code 0
- **SC-003**: `tdd/traceability.md` renders the `manual:` section with full FR text and a `manual:` tag for every manual FR, and the machine block's `manual:` count includes them — measured by parsing the rendered artifact
- **SC-004**: All FRs traced → byte-identical plan (backwards compat) — measured by planning an all-traced fixture and asserting the unit rows match the pre-change derivation
- **SC-005**: The full existing test suite for plan/parser/gate passes after the change except where a test asserted the old fallback-to-unit default, which MUST be updated to the new declared semantics — measured by `dart test` on the touched suites
