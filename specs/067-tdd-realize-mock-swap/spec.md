# Feature Specification: zfa tdd realize — Mock→Real Swap

**Feature Branch**: `067-tdd-realize-mock-swap`

**Created**: 2026-09-03

**Status**: Draft

**Input**: User description: "[ROADMAP P1] zfa tdd realize: mock→real swap with contract gate, differential gate, and nuance receipts — request from issue #913 (https://github.com/arrrrny/zuraffa/issues/913). The TDD ladder needs a `zfa tdd realize <entity|behavior> --adapter <real>` command that rebinds DI from the mock datasource to the real adapter behind the SAME generated interface, runs the MOCK-era contract suite unchanged against the real binding (any red = verdict names which side broke the contract), applies a differential gate comparing real vs mock on committed fixtures (extends the landed #832 simulate adapters) with a threshold from .zfa.json, and records any hand-delta in the feature's provenance ledger as a proof-carrying receipt (per #807 lineage). State transitions MOCKED → REAL; cycle-log carries era-tagged evidence. This is the keystone of the mock-first promise: mocks are 100% generatable, real impls are not — and this command is where the honest 90/10 becomes enforced physics."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Swap a single entity from mock to real adapter (Priority: P1)

A developer has completed a feature using generated mock datasources (all tests green under `complete(mocked)`). They have now written or selected a real adapter that implements the same interface. They run `zfa tdd realize Product --adapter ProductRestApi` and the system rebinds DI from the mock to the real adapter, runs the existing contract test suite unchanged against the real binding, and reports a verdict: either the real adapter satisfies the contract (green) or it names which tests failed and which side broke the contract.

**Why this priority**: This is the foundational capability. Without a working swap-and-verify loop, none of the downstream value (differential gating, receipt tracking, state transitions) is reachable. It is the single atomic action that proves the mock-first promise works.

**Independent Test**: Can be fully tested by running `zfa tdd realize` against a single entity with a known-passing real adapter and verifying: (a) the contract suite passes identically to the mock era, (b) the state transitions from MOCKED to REAL, (c) the cycle-log records era-tagged evidence.

**Acceptance Scenarios**:

1. **Given** an entity whose mock-era contract suite is all green, **When** the developer runs `zfa tdd realize <entity> --adapter <real>`, **Then** the system rebinds DI from the mock datasource to the real adapter behind the same generated interface, runs the full mock-era contract suite unchanged, and reports pass/fail with test-level granularity.

2. **Given** a real adapter that breaks one contract test, **When** the developer runs `zfa tdd realize`, **Then** the system reports which specific tests failed and produces a verdict identifying whether the real adapter or the test assumptions broke the contract (e.g., the mock assumed a different shape than the real API returns).

3. **Given** a successful realize run, **When** the developer checks the feature's state, **Then** the state has transitioned from MOCKED to REAL and the cycle-log contains era-tagged evidence entries (mock era vs. real era).

---

### User Story 2 - Differential gate catches real-vs-mock drift on committed fixtures (Priority: P1)

A developer runs `zfa tdd realize` and the contract suite passes, but the real adapter returns subtly different data than the mock (e.g., extra fields, different nullability, different serialization). The differential gate compares real adapter output against mock output on the feature's committed fixture data and flags any drift exceeding a configurable threshold.

**Why this priority**: Without the differential gate, a contract-passing real adapter can silently introduce behavioral differences that only surface in production. This is the "enforced physics" the feature description calls out — the honest 90/10 split must be measured, not assumed.

**Independent Test**: Can be tested by running `zfa tdd realize` with a real adapter known to return slightly different fixture data and verifying the differential gate fires, reports the delta, and either passes (within threshold) or fails (exceeds threshold).

**Acceptance Scenarios**:

1. **Given** a real adapter that returns fixture output within the configured tolerance threshold, **When** the differential gate runs after contract verification, **Then** the gate reports PASS with a drift summary showing the delta magnitude and threshold.

2. **Given** a real adapter that returns fixture output exceeding the configured tolerance threshold, **When** the differential gate runs, **Then** the gate reports FAIL, shows the specific field-level deltas, and the realize command exits non-zero.

3. **Given** no threshold configured in `.zfa.json`, **When** the differential gate runs, **Then** it uses a sensible default threshold (e.g., zero tolerance for structural differences, configurable percentage for numeric values).

---

### User Story 3 - Hand-delta receipt recorded in provenance ledger (Priority: P1)

When `zfa tdd realize` completes, the system records a proof-carrying receipt in the feature's provenance ledger documenting: which adapter was swapped, which contract tests passed/failed, the differential gate verdict, and any hand-delta between the generated mock and the real implementation (code that was written by hand rather than generated).

**Why this priority**: Receipts are the audit trail that makes the mock-first promise verifiable. Without them, there is no way to confirm which parts of the feature are generated (100% mock) vs. hand-written (real adapter code) — the "honest 90/10" becomes a claim rather than a proof.

**Independent Test**: Can be tested by running `zfa tdd realize`, then inspecting the provenance ledger file and verifying it contains a structured receipt with all required fields (adapter name, contract verdict, differential verdict, hand-delta ratio, lineage reference).

**Acceptance Scenarios**:

1. **Given** a completed `zfa tdd realize` run, **When** the developer inspects the feature's provenance ledger, **Then** a new receipt entry exists with fields: entity name, adapter name, state transition (MOCKED→REAL), contract suite verdict, differential gate verdict, hand-delta ratio, and a lineage reference linking to the mock-era receipts.

2. **Given** a receipt recorded, **When** the developer runs `zfa proof check`, **Then** the receipt digest is verified against the current tree and the check passes (exit 0).

3. **Given** a receipt with hand-delta (the real adapter has hand-written code), **When** the receipt is recorded, **Then** the hand-delta ratio accurately reflects the proportion of generated vs. hand-written code in the adapter path, and the receipt carries a flag indicating manual implementation exists.

---

### Edge Cases

- What happens when the specified adapter does not implement the generated interface? The system must detect this at DI rebinding time and report a clear error (adapter mismatch) before running any tests.
- What happens when the entity has no mock-era contract suite yet (e.g., the developer skipped mock testing)? The system must refuse to realize and require the contract suite to exist first.
- What happens when `.zfa.json` has no differential threshold configured? A safe default is applied; the default is documented and overridable.
- What happens when the realize command is run on an entity already in REAL state? The system must either skip gracefully (idempotent) or warn that re-realization is unnecessary — it must not corrupt the state or duplicate receipts.
- What happens when the contract suite is partially red (some tests pass, some fail)? The system reports the full verdict, records the receipt with partial results, and transitions state only if the full suite passes. Partial results are recorded but state remains MOCKED.
- What happens when the cycle-log is corrupted or missing? The realize command must not crash; it should create/rebuild the cycle-log entry and warn the user.
- What happens when two real adapters exist for the same interface? The `--adapter` flag must be unambiguous; if multiple adapters match, the system lists them and requires explicit selection.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a `zfa tdd realize <entity|behavior> --adapter <real>` command that initiates the mock-to-real swap workflow.
- **FR-002**: System MUST rebind DI from the current mock datasource to the specified real adapter behind the same generated interface without modifying the interface contract.
- **FR-003**: System MUST run the full mock-era contract test suite unchanged against the newly bound real adapter and report pass/fail at the test level.
- **FR-004**: System MUST produce a verdict that names which specific tests failed and distinguishes between "real adapter broke the contract" vs. "mock assumptions were wrong" when tests fail.
- **FR-005**: System MUST apply a differential gate that compares real adapter output against mock adapter output on the feature's committed fixture data.
- **FR-006**: System MUST read the differential threshold from `.zfa.json` and apply a sensible default when not configured.
- **FR-007**: System MUST record a proof-carrying receipt in the feature's provenance ledger after every realize run, containing: entity name, adapter name, state transition, contract verdict, differential verdict, hand-delta ratio, and lineage reference.
- **FR-008**: System MUST transition the entity state from MOCKED to REAL only when the full contract suite passes.
- **FR-009**: System MUST tag cycle-log entries with era information (mock era vs. real era) so that test evidence is traceable to its binding context.
- **FR-010**: System MUST reject realization when no mock-era contract suite exists for the target entity.
- **FR-011**: System MUST detect adapter interface mismatches at DI rebinding time and report clear errors before running tests.
- **FR-012**: System MUST be idempotent when realizing an entity already in REAL state (skip or warn, never corrupt).
- **FR-013**: System MUST calculate the hand-delta ratio accurately, distinguishing generated code from hand-written code in the adapter path.
- **FR-014**: System MUST support both entity-level and behavior-level realization targets via the command argument.
- **FR-015**: System MUST verify receipt digests via `zfa proof check` compatibility, linking to the lineage chain established by receipt system (#807).

### Key Entities

- **Realize Command**: The CLI entry point that orchestrates the entire mock-to-real swap workflow — DI rebinding, contract execution, differential gating, receipt recording, and state transition.
- **Contract Suite**: The collection of test cases generated or maintained during the mock era; these tests exercise the entity's interface and must pass unchanged when the real adapter is bound.
- **Differential Gate**: A verification step that compares real adapter outputs against mock adapter outputs on committed fixture data, applying a configurable tolerance threshold.
- **Provenance Ledger**: A per-feature file that accumulates proof-carrying receipts documenting every state transition, adapter swap, and hand-delta.
- **Receipt**: A structured, digest-verified record of a realize run, including adapter name, verdicts, hand-delta ratio, and lineage chain.
- **Entity State**: The lifecycle state of an entity's adapter binding, transitioning through MOCKED → REAL (and potentially back if re-realization is needed).
- **Cycle-Log**: The running log of TDD cycle evidence, now enhanced with era tags to distinguish mock-era evidence from real-era evidence.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can swap any entity from mock to real adapter and receive a contract verdict within the same time as running the existing test suite (no more than 2x overhead for the full realize workflow).
- **SC-002**: The differential gate catches 100% of structural differences (field additions/removals/type changes) between real and mock adapter outputs on committed fixtures.
- **SC-003**: Every `zfa tdd realize` run produces a verifiable receipt that passes `zfa proof check` with zero manual intervention.
- **SC-004**: State transitions are accurate: an entity in MOCKED state moves to REAL only after full contract pass; partial failures leave state as MOCKED with a diagnostic receipt.
- **SC-005**: Cycle-log entries are era-tagged and can be filtered or queried by era (mock vs. real) without parsing ambiguity.
- **SC-006**: The realize command handles adapter mismatches, missing contract suites, and idempotent re-runs gracefully — producing clear, actionable error messages in every case.

## Assumptions

- The mock-era contract test suite exists for any entity targeted by `zfa tdd realize`. The command does not generate the contract suite — it consumes one that was created during the mock TDD phase.
- The `--adapter <real>` argument refers to a concrete adapter that has been registered in the project's DI container (e.g., via `zfa make --di` or manual registration). The command does not create adapters.
- The differential threshold in `.zfa.json` uses a well-defined schema (to be specified by the `spec-differential-threshold` configuration, defaulting to zero structural tolerance and 0% numeric drift).
- Receipts follow the proof-carrying receipt format established by the lineage system (#807) and can be verified by `zfa proof check`.
- The entity state model (MOCKED, REAL) is managed by the existing state tracking infrastructure and this command adds the MOCKED → REAL transition.
- The cycle-log exists for any entity that has been through at least one mock-era TDD cycle; the realize command appends to it rather than creating it from scratch.
- The `--adapter` flag accepts a single adapter name; batch realization (multiple adapters at once) is out of scope for v1 and can be added later.
