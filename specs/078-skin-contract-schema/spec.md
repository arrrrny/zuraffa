**Template Version**: `zuraffa-1.0`

# Feature Specification: skin-contract.v1 — Typed Model, Parser, and JSON Schema Emitter

**Feature Branch**: `078-skin-contract-schema`

**Created**: 2026-09-05

**Status**: Draft

**Input**: User description: "GitHub issue #1164 (stage 1/4 of #1111): skin-contract.v1 typed model + parser + JSON Schema emitter emitted by `zfa tdd plan` when a spec carries `## Skin Contract:`; schema test walking every contract-bearing spec."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Parse a skin contract from a spec (Priority: P1)

A developer (or pipeline step) working with a spec that declares a `## Skin Contract:` section wants that declaration as typed, machine-readable data — routes, states, platform rows, state rows, schema version — instead of prose. They hand the raw contract JSON to a parser and get a validated model back, or a named error that says exactly what is missing or malformed.

**Why this priority**: Every other stage of #1111 consumes this model; without a parser there is no contract, only decoration.

**Independent Test**: Feed a known-valid contract JSON through the parser and get a model with every field populated; feed malformed input and get a specific error.

**Acceptance Scenarios**:

1. **Given** contract JSON containing routes, states, platform rows, state rows, and a schema version, **When** the parser runs, **Then** a typed model is returned with every field populated and the schema version reported.
2. **Given** contract JSON missing a required section or carrying an unknown structure, **When** the parser runs, **Then** it fails with an error naming the offending section/key — never a silent default.

---

### User Story 2 - The schema is generated, not hand-maintained (Priority: P2)

A maintainer wants the JSON Schema artifact to always match the typed model. When `zfa tdd plan` runs on a spec carrying `## Skin Contract:`, it writes `04-skin-contract.schema.json` derived from the model — so the schema can never drift from the code that parses it.

**Why this priority**: The schema is the machine-checkable contract surface; hand-maintaining it invites exactly the drift the contract exists to prevent.

**Independent Test**: Run `zfa tdd plan` on a contract-bearing spec and verify the schema file is written, is valid JSON Schema, and covers every model field.

**Acceptance Scenarios**:

1. **Given** a spec with `## Skin Contract:`, **When** `zfa tdd plan` runs, **Then** `04-skin-contract.schema.json` is written next to the lane plan (issue #1111 SC-1).
2. **Given** the emitted schema, **When** it is compared against the typed model's fields, **Then** every model field has a schema property and every schema property traces to a model field (no drift, no orphans).
3. **Given** a spec without a Skin Contract section, **When** `zfa tdd plan` runs, **Then** no schema file is written and nothing else about the plan changes.

---

### User Story 3 - Every declared contract is schema-conformant, proven continuously (Priority: P2)

A maintainer wants a standing guarantee that every contract declared in the repo's specs parses and validates: a test that walks every contract-bearing spec, parses its JSON, and validates it against the emitted schema, failing with the offending spec named.

**Why this priority**: This is the enforcement that keeps declarations honest as specs evolve; it is what stages 2 and 4 of #1111 will stand on.

**Independent Test**: Run the schema test suite; it discovers every contract-bearing spec, validates each, and passes — or names the failing spec and key.

**Acceptance Scenarios**:

1. **Given** the repo's specs tree, **When** the schema test suite runs, **Then** every spec with a Skin Contract section is discovered, parsed, and schema-validated, and all pass.
2. **Given** a spec whose contract JSON violates the schema, **When** the suite runs, **Then** it fails naming the spec file and the violating key.

---

### Edge Cases

- What happens when a spec declares `## Skin Contract:` but provides no JSON body? The plan step fails naming the spec — an empty contract is not a valid contract.
- What happens when contract JSON carries fields the model does not know? The parser fails naming the unknown key (strict parsing — unknown fields are contract drift, not future-proofing).
- What happens when two specs declare the same route? Each spec's contract is validated independently; cross-spec collision detection is out of scope for this stage.
- What happens when the schema file already exists from a previous plan run? It is overwritten with the freshly generated schema (deterministic regeneration, like the receipts convention).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a typed skin-contract model with schema version, routes, states, platform rows, and state rows.
- **FR-002**: The system MUST parse contract JSON into the model, failing with an error that names the offending section or key when input is malformed, incomplete, or carries unknown fields.
- **FR-003**: The system MUST serialize the model back to contract JSON that parses to an equal model (round-trip guarantee).
- **FR-004**: `zfa tdd plan` MUST emit `04-skin-contract.schema.json` derived from the model when (and only when) the target spec carries a `## Skin Contract:` section.
- **FR-005**: The emitted schema MUST be generated from the typed model's fields so the two cannot drift.
- **FR-006**: A test suite MUST walk every spec with a Skin Contract section, parse its contract, and validate it against the schema, failing with the spec path and violating key named.
- **FR-007**: The emitted schema MUST itself be valid JSON Schema (machine-parseable by standard validators).

### Key Entities *(include if feature involves data)*

- **Skin Contract (v1)**: a spec-declared declaration of the skin's surface — routes (path → view), states (loading/error/empty per view), platform rows (adaptive slots per platform), state rows (audit rows for state handling), and the schema version it conforms to.
- **Skin Contract Schema**: the JSON Schema artifact generated from the model; the validation authority for every declared contract.

## Lanes *(include when the feature splits engine vs. skin)*

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1-A3, U1-U7]
    flutter_allowed: false
  - lane: SKIN
    behaviors: []
    flutter_allowed: true
  - lane: BOTH
    behaviors: []
    flutter_allowed: conditionally
```

This stage is pure Dart (model, parser, emitter, tests) — no Flutter surface. The skin lane consumes the contract in stages 2-4 (#1165, #1167).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A valid contract JSON parses to a fully populated model; malformed input fails naming the offending key — 100% of the time, no silent defaults.
- **SC-002**: `zfa tdd plan` on a contract-bearing spec writes a valid, model-derived schema file; on a spec without the section, it writes nothing new.
- **SC-003**: The schema test suite validates every contract-bearing spec in the repo and passes — or names the failing spec and key.
- **SC-004**: Model → JSON → model round-trips are lossless for every field.

## Assumptions

- The contract JSON lives inside the spec's `## Skin Contract:` section (fenced JSON), as established by the #1074/#1111 lineage.
- Strict parsing is the default: unknown fields fail. Forward compatibility is handled by bumping the schema version, not by ignoring unknowns.
- The schema file name and location follow the existing lane-plan convention (`04-skin-contract.schema.json` beside the lane plan under `specs/<feature>/tdd/`).
- Cross-spec route collision detection and runtime consumption are stages 2-4's concern (#1165, #1166, #1167), not this stage's.
- The stage ships in the CORE lane of the target feature's own specs only if it declares a Skin Contract; the emitter's first real customer is the 006-login-skin spec.
