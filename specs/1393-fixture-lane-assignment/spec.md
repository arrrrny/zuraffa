**Template Version**: `zuraffa-1.0`

# Feature Specification: 1393-fixture-lane-assignment

GitHub issue: arrrrny/zuraffa#1393 (verify-misfire / spec-drift, EPIC #1012
Phase A/B — exit criterion 4, sub-issue #1000 lane markers).

## Summary

The flagship fixture `example/specs/004-login-ui` cannot complete its own
engine cycle: U1 (FR-001, "present the adaptive login view with the
declared platform slots") is a *presentation* behavior declared in the
CORE lane, contradicting the CORE=engine-only contract. FR-001's unit
make stops vacuous-green (the guard works as designed — issues
#1259/#1308 — the fixture feeds it an unmakeable behavior), and with U1
moved to SKIN the A1/A2 acceptance makes report `unexpressible` because
the fixture declares zero engine-side unit behaviors with contract
traces for the spec 052 composition to anchor on. The engine half only
reaches green after hand work, so EPIC #1012 exit criterion 4
("004-login-ui is re-split; engine half green without Flutter in test
tree") is not demonstrable unattended.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The re-split fixture drives its engine lane unattended (Priority: P1)

A verifier clones the repo and runs `zfa tdd run 004-login-ui` against
the example fixture. The engine lane (CORE) drives gen → verify-red →
make → refactor for every CORE behavior and completes green with no
hand edits: the engine-side unit behavior scaffolds from its declared
scalar-return contract, and the acceptance makes compose from the green
unit anchor through the spec 052 composition.

**Why this priority**: exit criterion 4 is the epic deliverable; without
an unattended engine half the verify phase cannot certify the split.

**Independent Test**: run the engine cycle on the committed fixture and
read `tdd/04-engine-receipt.json` — verdict green, result complete,
stopped_at null.

**Acceptance Scenarios**:

1. **Given** the committed fixture, **When** `zfa tdd plan
   004-login-ui` runs, **Then** the split receipt classifies U1 as SKIN
   and the CORE lane carries no presentation-traced unit behavior.
   **Type**: acceptance
2. **Given** the committed fixture, **When** the engine cycle runs,
   **Then** the engine-side unit behavior routes DECLARED to a
   scalar-return callable contract row (func surface), not the
   view-generation surface. **Type**: acceptance
3. **Given** the committed fixture, **When** `zfa tdd run 004-login-ui`
   drives the engine lane, **Then** the receipt verdict is green with
   every behavior DONE and no hand edits to any subject or test.
   **Type**: acceptance

### User Story 2 - The Skin Contract declaration stays machine-parseable (Priority: P2)

The strict adaptive-skin-contract parser (issue #1004) accepts the
fixture's `## Skin Contract` yaml; the malformed
`adaptive_slots: obile, ios, android, macos]` named in the issue can
never reappear unnoticed.

**Why this priority**: the malformed yaml was already repaired on
master (spec 1377 recorded the repair); the residual need is the
regression pin.

**Independent Test**: run the strict parser over the committed spec and
assert the declared platform matrix.

**Acceptance Scenarios**:

1. **Given** the committed fixture spec, **When** the strict parser
   runs, **Then** it returns the contract with adaptive slots
   [mobile, ios, android, macos] and never a parse exception.
   **Type**: acceptance

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The fixture's Lanes declaration MUST place U1 (FR-001,
  the adaptive view presentation) in the SKIN lane, and the CORE lane
  MUST NOT declare a behavior whose contract trace routes to a
  presentation row.
      traces: split_receipt_classification
- **FR-002**: The fixture MUST declare at least one engine-side unit
  behavior whose `traces:` binds to a declared callable contract row
  with a scalar-return signature, so gen derives an outcome assertion
  and make scaffolds green without a hand step.
      traces: engine_unit_contract
- **FR-003**: The committed split evidence MUST carry the re-split
  classification (A1/A2/U2 CORE; W1/U1/A3-A7 SKIN) so the two-cycle
  driver resolves the lanes from the receipt.
      traces: split_receipt_classification
- **FR-004**: The `## Skin Contract` yaml MUST remain valid under the
  strict parser.
      traces: skin_contract_parser

## Layer Contracts

**Domain**:

- `split_receipt_classification`: `classify(spec_lanes) -> Classification` — the
  committed `tdd/split-receipt.json` the driver reads.

**Function**:

- `engine_unit_contract`: `assertScalarReturn(row) -> bool` — the fixture's
  traced contract row declares a scalar-return callable signature.
- `skin_contract_parser`: `parse(spec_md) -> AdaptiveSkinContract` — the strict
  production parser over the committed spec.

## Key Entities

| Entity | Fields | Purpose |
|--------|--------|---------|
| `FixtureSpec` | `lanes`, `functional_requirements`, `skin_contract` | The committed fixture markdown the loop consumes |
| `Classification` | `behavior_id -> CORE\|SKIN\|BOTH` | The committed lane assignment the driver trusts |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The structural pin suite (B1–B4) passes: U1 in SKIN, the
  CORE lane's unit traces to a scalar-return callable row, the strict
  parser accepts the Skin Contract, and the committed split receipt
  carries the re-split classification.
- **SC-002**: `zfa tdd run 004-login-ui` drives the engine lane to
  green unattended: `tdd/04-engine-receipt.json` verdict `green`,
  result `complete`, stopped_at `null`, counts done = total = 3
  (A1, A2, U2) — EPIC #1012 exit criterion 4 demonstrable.
- **SC-003**: `dart analyze` reports no issues on every file this fix
  adds or changes, and `dart format` leaves zero formatting diffs on
  those files.
