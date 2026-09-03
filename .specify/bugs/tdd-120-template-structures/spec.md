# Feature Specification: zfa tdd plan consumes the zuraffa-1.0 template's declared structures

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `fix/tdd-120-template-structures`

**Created**: 2026-09-03

**Status**: Approved

**Input**: Bug issue #919 ([TDD-120]): the zuraffa-1.0 spec template declares structures
zfa must consume — Key Entities table, External Dependencies & Contracts table, Layer
Contracts, Template Version pin — but `zfa tdd plan` only parses the legacy core sections.

**Scope note**: This fix is plan-side complete. Make-side consumption of the declared
structures (mock routing via `zfa mock create`, signature-consistent interface
generation) is #909's territory and is explicitly out of scope here.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Table-Declared Entities Reach Phase-0 (Priority: P1)

A developer authors a spec from the zuraffa-1.0 template whose Key Entities section is a
markdown table. `zfa tdd plan` extracts every declared entity, and `zfa tdd run` phase-0
creates each one via `zfa entity create` — exactly as the legacy bullet format does today.

**Why this priority**: Without this, table-authored specs drive behaviors with no phase-0
entity creation; unit behaviors route to func-stubs.

**Independent Test**: Plan a spec whose Key Entities section is a `| Entity | Fields | Purpose |`
table and verify the test-list artifact lists each entity with its fields, and that the
existing TestListReader phase-0 path picks them up unchanged.

**Acceptance Scenarios**:

1. **Given** a spec whose Key Entities section is a zuraffa-1.0 markdown table with row
   `| ShoeSizePreference | `id: String`, `sizeEu: double` | One saved size |`,
   **When** `zfa tdd plan` runs, **Then** the test-list artifact's Key entities table
   contains `ShoeSizePreference` with fields `id:String` and `sizeEu:double`.
2. **Given** a spec whose Key Entities section uses the legacy bullet format
   (`- **Name**: prose with `field: Type` pairs`), **When** `zfa tdd plan` runs,
   **Then** entities are extracted exactly as before (no regression).
3. **Given** a planned spec whose entities came from a table, **When** `zfa tdd run`
   reaches make, **Then** phase-0 runs `zfa entity create -n <Name> --field <n>:<T> ...`
   for each declared entity via the existing test-list reading path.

### User Story 2 - Template Version Pins The Contract (Priority: P1)

The Template Version marker is the treaty pin. A spec without a known version is contract
drift and must fail loudly at plan time, not confuse downstream.

**Why this priority**: Strict per issue #919 — any spec without a known Template Version
is drift; legacy specs gain the marker to plan.

**Independent Test**: Run `zfa tdd plan` on a spec with the marker removed and on one with
`zuraffa-2.0`; both must exit 3 with a fix line, no artifacts written.

**Acceptance Scenarios**:

1. **Given** a spec missing the `**Template Version**` marker, **When** `zfa tdd plan`
   runs, **Then** the command exits with code 3, prints a `--> fix:` line pointing at the
   zuraffa extension template, and writes no plan artifacts.
2. **Given** a spec carrying an unknown version (`zuraffa-2.0`), **When** `zfa tdd plan`
   runs, **Then** the command exits with code 3 naming the offending version, with a
   `--> fix:` line, and writes no plan artifacts.
3. **Given** a spec carrying `**Template Version**: `zuraffa-1.0``, **When**
   `zfa tdd plan` runs, **Then** planning proceeds (the pin is accepted).

### User Story 3 - Declared Dependencies And Layer Contracts Land In The Plan Artifact (Priority: P2)

The zuraffa-1.0 template's External Dependencies & Contracts table and Layer Contracts
section must be extracted into the plan artifact so #909's mock-first make path can
consume them, and undeclared externals must be caught at plan time.

**Why this priority**: The dependencies table is the input for the mock-first make path;
today it is parsed by nothing.

**Independent Test**: Plan a spec with both sections and verify the test-list artifact
carries them; reference an undeclared external in a requirement and verify exit 2.

**Acceptance Scenarios**:

1. **Given** a spec with an External Dependencies & Contracts table
   (`| Dependency | Type | Contract | Mock Priority |`), **When** `zfa tdd plan` runs,
   **Then** the test-list artifact contains every row's dependency, type, contract, and
   mock priority.
2. **Given** a spec with a Layer Contracts section declaring interface signatures per
   layer, **When** `zfa tdd plan` runs, **Then** the test-list artifact contains each
   declared layer, interface name, and method signature.
3. **Given** a requirement statement referencing a known external dependency that is not
   declared in the spec's dependencies table, **When** `zfa tdd plan` runs, **Then** the
   command exits with code 2 naming the undeclared dependency and a `--> fix:` line.

---

### Edge Cases

1. **Given** a spec with no Key Entities section at all, **When** `zfa tdd plan` runs,
   **Then** planning proceeds with zero declared entities (as today).
2. **Given** a spec whose Key Entities section mixes a table and legacy bullets,
   **When** `zfa tdd plan` runs, **Then** entities from both forms are extracted.
3. **Given** a spec with no External Dependencies table and no external references in
   requirements, **When** `zfa tdd plan` runs, **Then** no dependency lint fires.

## Requirements *(mandatory)*

- **FR-001**: `SpecParser.parseKeyEntities` MUST extract entity name (column 1),
  fields as `name:Type` pairs (column 2, backtick-enclosed), and purpose (column 3) from
  `| Entity | Fields | Purpose |` markdown table rows.
- **FR-002**: `SpecParser.parseKeyEntities` MUST continue to extract legacy
  `- **Name**: description` bullets with backticked `field: Type` pairs, unchanged.
- **FR-003**: The spec parser MUST read the `**Template Version**: `x`` marker and report
  the declared version, distinguishing known (`zuraffa-1.0`) from unknown and missing.
- **FR-004**: The spec parser MUST extract External Dependencies & Contracts table rows
  into dependency records (dependency, type, contract, mock priority).
- **FR-005**: The spec parser MUST extract Layer Contracts declarations into records of
  layer, interface name, and declared method signatures.
- **FR-006**: `zfa tdd plan` MUST exit with code 3 and a `--> fix:` line — writing no
  artifacts — when the Template Version marker is missing or not a known version.
- **FR-007**: `zfa tdd plan` MUST exit with code 2, naming the dependency and a
  `--> fix:` line, when a requirement references a known external dependency not declared
  in the dependencies table.
- **FR-008**: `zfa tdd plan` MUST render extracted dependencies and layer contracts into
  the `tdd/test-list.md` artifact.
- **FR-009**: `TestListReader` MUST read the dependencies and layer-contract sections
  back from the test-list artifact so downstream consumers (#909) can use them.

## Success Criteria *(mandatory)*

1. A zuraffa-1.0-table-authored spec plans cleanly, its entities reach phase-0, and the
   plan artifact carries dependencies + layer contracts.
2. Specs without a known Template Version exit 3 at plan time with a fix line.
3. Undeclared externals in requirements exit 2 at plan time with a fix line.
4. Legacy bullet-format specs (with the marker added) plan identically to before.

## Assumptions

- The zuraffa-1.0 grammar is pinned to the section shapes embedded verbatim in issue #919.
- `zfa tdd plan` exits 3 *before* any artifact write when the version gate fails.
- The undeclared-dependency lint matches requirement statements against the set of
  external dependency names zfa already knows about (adapters/backends it can generate).
