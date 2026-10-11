**Template Version**: `zuraffa-1.0`

# Feature Specification: skin-contract runtime binding (pure Dart)

**Feature Branch**: `079-skin-contract-binding`

**Created**: 2026-09-05

**Status**: Draft

**Input**: User description: "GitHub issue #1165 (stage 2/4 of #1111): the skin contract becomes runtime consumable — a pure-Dart binding that maps a parsed SkinContract to the runtime kit's inputs (route table, audit rows, toaster/state bindings), so the Flutter shell (zuraffa_flutter) consumes the contract with zero hand-written wiring. Engine stays pure Dart; skin UI has Flutter."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Contract routes become the runtime route table (Priority: P1)

A consumer (the Flutter shell) holding a parsed `SkinContract` wants the route half of the runtime contract ready to use: the exact `RouteContractTable` the route observer validates pushes against, built from `contract.routes` with zero manual copying.

**Why this priority**: Routes are the contract's backbone; the route observer exists since #1102 and needs a declared source of truth.

**Independent Test**: Parse a contract with known routes, derive the table, and verify allowed routes match exactly (and undeclared pushes still violate).

**Acceptance Scenarios**:

1. **Given** a contract declaring routes `/login` and `/register`, **When** the binding derives the route table, **Then** both are allowed, an undeclared `/settings` push violates, and the navigator root still conforms by construction.
2. **Given** a contract with no routes, **When** the binding derives the table, **Then** no route except the root is allowed.

---

### User Story 2 - Contract state rows become audit rows and toaster bindings (Priority: P1)

A consumer wants the audit half ready: from `contract.stateRows` and `contract.states`, the binding produces the audit-row descriptors the kit reconciles against, and the toaster/empty bindings — which views report errors through the toaster vs. inline, which declare empty states.

**Why this priority**: This is the "audit chrome + toaster without call-site code" half of #1165.

**Independent Test**: Parse a contract, derive the audit rows and state bindings, and verify each view's error/empty declaration maps to the right binding kind.

**Acceptance Scenarios**:

1. **Given** a contract whose `states` declare `error: toaster` for LoginPage and `error: inline` for RegisterPage, **When** the binding derives state bindings, **Then** LoginPage maps to the toaster binding and RegisterPage to inline.
2. **Given** a contract whose `stateRows` declare two audit rows, **When** the binding derives the row descriptors, **Then** both descriptors carry their declared ids and kinds.

---

### User Story 3 - The binding is one call and honors contract identity (Priority: P2)

A consumer wants the whole runtime binding in one object built in one call from one contract, carrying the contract's identity (feature/contract name) so violations and receipts can name where a row came from.

**Why this priority**: The #1165 goal is "zero call-site wiring"; one binding object is what the shell mounts.

**Independent Test**: Build the binding from a contract, verify routes + state bindings + identity are all present and consistent.

**Acceptance Scenarios**:

1. **Given** a parsed contract, **When** the binding is built, **Then** it exposes the route table, the state bindings, and the contract name it was built from.
2. **Given** two different contracts, **When** bindings are built, **Then** each keeps its own identity and route set (no cross-contamination).

### Edge Cases

- What happens when a contract declares the navigator root `/` as a route? It conforms by construction anyway; the binding must not double-register or fail.
- What happens when `states` and `stateRows` disagree about a view? They are different declaration surfaces (state handling vs. audit rows); the binding validates neither against the other at this stage — reconciliation is the kit's runtime job.
- What happens when a route path duplicates another? The table deduplicates (set semantics); duplicates are not an error.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a pure-Dart runtime binding built from a parsed `SkinContract` in one call.
- **FR-002**: The binding MUST derive the runtime route table from `contract.routes`, preserving the navigator-root conforming-by-construction rule.
- **FR-003**: The binding MUST derive per-view state bindings from `contract.states` distinguishing toaster, inline, and none error handling, plus empty-state declarations.
- **FR-004**: The binding MUST derive audit-row descriptors from `contract.stateRows` carrying the declared id and kind.
- **FR-005**: The binding MUST carry the contract's declared name/identity so downstream violations and receipts can name their source.
- **FR-006**: The binding MUST stay free of any UI-framework dependency (engine lane, pure Dart).
- **FR-007**: The binding MUST be exported from the skin barrel for the Flutter shell to consume across the package boundary.

### Key Entities *(include if feature involves data)*

- **SkinContractRuntimeBinding**: the pure object the Flutter shell mounts — route table, state bindings, audit-row descriptors, contract identity.
- **StateBinding**: per-view declaration of how error and empty states surface (toaster / inline / none; empty declared or not).

## Lanes *(include when the feature splits engine vs. skin)*

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1-A3, U1-U5]
    flutter_allowed: false
  - lane: SKIN
    behaviors: []
    flutter_allowed: true
  - lane: BOTH
    behaviors: []
    flutter_allowed: conditionally
```

The binding itself is CORE (pure Dart); the Flutter shell that mounts it is the zuraffa_flutter package's stage-2 half (same issue, separate repo/PR).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: One call maps a parsed contract to a complete runtime binding — routes, state bindings, audit rows, identity.
- **SC-002**: Derived route tables reproduce #1102's semantics exactly (root conforms, undeclared violates, null/empty names conform).
- **SC-003**: The binding module has zero UI-framework imports, provable by the analyzer.
- **SC-004**: The zuraffa_flutter shell can mount the binding without any hand-written contract wiring.

## Assumptions

- The Flutter shell half of this stage lands in the zuraffa_flutter package (its own repo/PR), consuming this binding through `package:zuraffa/skin.dart`.
- Reconciliation of contract rows against live audits remains the kit's runtime job; this stage only produces the declared bindings.
- Contract identity comes from the `## Skin Contract: <name>` heading name, carried through parsing.
