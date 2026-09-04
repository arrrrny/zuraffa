# Feature Specification: UI Coverage Ledger + XRay Gatekeeper (every surface traced to a green behavior; untraced = merge blocked)

**Feature Branch**: `075-ui-coverage-ledger`

**Created**: 2026-09-03

**Status**: Draft

**Template Version**: `zuraffa-1.0`

**Input**: User description: "https://github.com/arrrrny/zuraffa/issues/963 — [ZIKZAK-REBUILD] UI coverage ledger + XRay gatekeeper: every text/route/affordance traced to a green behavior; untraced surface = merge blocked; overlay shows gaps live."

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| --- | --- | --- | --- |
| XRayOverlay | service | enable() -> void, paint(state) -> void | P2 |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The plan enumerates the feature's UI surface into a ledger (Priority: P1)

Per feature, the plan produces a **UI surface ledger** alongside the traceability matrix: every declared UI surface — static texts (the quoted-literal contract), declared routes (the Presentation contract row), and interactive affordances (buttons, inputs named in scenarios) — becomes one ledger row carrying the surface, its kind, the behavior(s) that prove it, and its state. The ledger is machine-owned: it derives from the spec's declarations, and a surface that no behavior traces to is a row with no prover — visible immediately, at plan time.

**Why this priority**: Coverage that isn't enumerated is a vibe. The ledger turns "everything is traced" from a feeling into a checkable list — the precondition for any gate.

**Independent Test**: Can be fully tested by planning a login-shaped spec declaring 8 production strings, 1 route, and 3 affordances, then confirming the ledger has exactly those rows with kinds and provers (or visibly empty provers). Delivers: the feature's UI surface as a checkable list, not a claim.

**Acceptance Scenarios**:

1. **Given** a spec whose scenarios quote 8 production strings, declare a route row, and name 3 button affordances, **When** the plan runs, **Then** the ledger contains one row per surface with kind text/route/affordance.
   **Type**: acceptance
2. **Given** the produced ledger, **When** a surface's proving behaviors are green, **Then** its state reads DONE with the proving behavior ids named.
   **Type**: acceptance
3. **Given** a surface no behavior traces to, **When** the plan runs, **Then** the row exists with an empty prover and a state marking it unproven — visible at plan time, not after merge.
   **Type**: acceptance
4. **Given** a scenario quoted literal that names no production surface (an example value), **When** the plan runs, **Then** it is not forced into the ledger (the ledger's source is the declared Presentation/route contract plus scenario surface markers, not every quotation).
   **Type**: acceptance

---

### User Story 2 - The coverage gate blocks merge on unproven surfaces (Priority: P2)

The coverage verdict is a gate: a machine-readable JSON report (one line per surface: proven-by, state) with an exit code — exit 0 only when every ledger row is DONE; otherwise exit non-zero naming each unproven surface and the behavior to write. CI-able. Wired as a merge/landing gate: a feature whose UI ledger is incomplete cannot land as proven.

**Why this priority**: The ledger measures; the gate enforces. Without it, unproven surfaces ship silently — the exact "coverage is a vibe" failure the issue names.

**Independent Test**: Can be fully tested by running the gate on a complete ledger (exit 0) and on a ledger with one unproven affordance (exit non-zero naming it), and by wiring the gate into merge and confirming a blocked landing names the gap. Delivers: untraced surface = merge blocked, mechanically.

**Acceptance Scenarios**:

1. **Given** a ledger where every row is proven by a green behavior, **When** the coverage gate runs, **Then** it exits 0 with a JSON verdict listing each surface proven.
   **Type**: acceptance
2. **Given** a ledger with one unproven affordance, **When** the gate runs, **Then** it exits non-zero and the verdict names the surface and its missing prover.
   **Type**: acceptance
3. **Given** the gate wired into merge, **When** a feature with an incomplete ledger lands, **Then** merge is blocked with the gap named.
   **Type**: acceptance
4. **Given** a behavior that is planned but not green, **When** the gate runs, **Then** the surfaces it would prove read NOT-DONE (green is the only proof).
   **Type**: acceptance

---

### User Story 3 - The XRay overlay paints ledger state on the running app (Priority: P3)

With the XRay plugin enabled, the running app paints surfaces by ledger state — proven surfaces render clean, unproven surfaces are highlighted — driven by the coverage ledger as its source of truth. The existing overlay + control deck machinery becomes the human-facing view of the ledger: what's proven, live, where the gaps are.

**Why this priority**: The overlay makes coverage visible to humans at exactly the moment they look at the UI — gaps stop being CI trivia and become on-screen facts.

**Independent Test**: Can be fully tested by enabling xray in a harness app with a seeded ledger and confirming the overlay highlights exactly the unproven surfaces and leaves proven ones clean. Delivers: the gap list, live on screen.

**Acceptance Scenarios**:

1. **Given** a harness app with the login ledger seeded (one unproven affordance), **When** xray is enabled and the app renders, **Then** the overlay highlights exactly the unproven affordance and paints proven surfaces clean.
   **Type**: acceptance
2. **Given** the overlay, **When** a surface's ledger state changes to proven, **Then** the overlay reflects the new state on the next paint.
   **Type**: acceptance
3. **Given** the control deck, **When** opened, **Then** it lists the ledger rows with their states (the deck drives the ledger, not a separate inventory).
   **Type**: acceptance

---

### User Story 4 - The deck drives certified mocks with real entries out of the box (Priority: P4)

The XRay control deck drives the feature's certified mocks: the existing `@XRayMock` scaffolder and scenario YAML wire to the dependency mocks (072's rail) so the deck's entries exist without hand authoring — a demo on mocked touchpoints shows what's proven, live.

**Why this priority**: An empty deck is a dead demo. Wiring the scaffolder to the dependency-mock rail means every declared touchpoint appears in the deck the moment its mock is generated — the simulation world populates itself.

**Independent Test**: Can be fully tested by generating dependency mocks for a declared spec, running the scaffolder, and confirming the deck lists each touchpoint with drive-able scenarios from the mock's fixture lane. Delivers: a live demo surface that builds itself from declarations.

**Acceptance Scenarios**:

1. **Given** a feature with generated dependency mocks (072), **When** the xray mock scaffolder runs, **Then** the deck lists each touchpoint with drive-able scenario entries.
   **Type**: acceptance
2. **Given** the deck driving a touchpoint, **When** a scenario is selected, **Then** the certified fake serves the scripted responses (the demo runs on the certification, not a parallel fake).
   **Type**: acceptance
3. **Given** a touchpoint with no generated mock, **When** the scaffolder runs, **Then** it names `zfa mock dependency <Name>` as the fix — no hand-authored stand-ins.
   **Type**: acceptance

---

### Edge Cases

- What happens when two scenarios declare the same surface (the same quoted string twice)? One ledger row, both provers listed — the surface is proven when ANY of its provers is green.
- What happens when a proving behavior's green is later invalidated (spec drift)? The ledger state recomputes from current evidence; a stale DONE is not honored (the gate re-checks green at run time).
- What happens when a surface's text is dynamic (built, not literal)? Only declarable surfaces enter the ledger; dynamic composition is out of scope and noted, never guessed.
- What happens when xray is enabled with no ledger for the feature? The overlay reports "no ledger" rather than painting everything proven — absence of data is not proof.
- What happens when the gate runs on a feature with zero declared UI surfaces? Trivially exit 0 with an empty verdict (nothing to prove), not an error.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The plan MUST produce a per-feature UI surface ledger enumerating declared surfaces — static texts (quoted-literal contract), declared routes (Presentation contract row), and named affordances — each with kind, proving behavior ids, and state.
- **FR-002**: A surface with no tracing behavior MUST appear in the ledger as unproven at plan time (visible, never omitted).
- **FR-003**: Ledger state MUST derive from current evidence: a surface is DONE only when at least one of its provers is green; planned-but-red provers never count.
- **FR-004**: `zfa tdd coverage` (the coverage gate) MUST emit a machine-readable JSON verdict (one line per surface: kind, proven-by, state) and exit 0 only when every row is DONE; failures name each unproven surface and its missing prover.
- **FR-005**: The coverage gate MUST be wireable as a merge/landing gate: an incomplete ledger blocks the landing naming the gaps (composing with the conformance verdict of 074).
- **FR-006**: With xray enabled, the overlay MUST paint surfaces by ledger state (proven clean, unproven highlighted), reading the ledger as its source of truth; with no ledger present it MUST report absence, never paint proof.
- **FR-007**: The control deck MUST list ledger rows with states, and the xray mock scaffolder MUST wire to 072's dependency mocks so deck entries exist without hand authoring; a missing mock names the generation fix.
- **FR-008**: Every refusal and gate failure MUST name the surface, the ledger row, or the missing artifact with a `--> fix:` hint.

### Key Entities *(include if feature involves data)*

- **UISurface**: one declared UI element — text (quoted literal), route (Presentation row), or affordance (named in a scenario) — with its kind.
- **LedgerRow**: surface + kind + proving behavior ids + state (DONE/NOT-DONE), recomputed from live evidence.
- **CoverageVerdict**: the gate's machine-readable JSON result (per-row lines, exit-coded).
- **XRayBinding**: the overlay/deck binding of ledger state to the running app and the deck's drive-able mock scenarios.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A login-shaped spec declaring 8 production strings, `/login`, and 3 affordances produces a ledger of exactly those rows; 100% traced shows 100% DONE, and any seeded gap is named by the gate.
- **SC-002**: The gate's JSON verdict is exit-coded and CI-able: complete ledger exits 0, one seeded unproven surface exits non-zero naming it.
- **SC-003**: With xray enabled, a seeded unproven surface is highlighted live and proven surfaces render clean; absence of a ledger reports as such.
- **SC-004**: After generating dependency mocks, the deck lists every touchpoint with drive-able scenarios without any hand-authored entries.
- **SC-005**: A merge with an incomplete ledger is blocked naming the gaps (gate composed with 074's conformance verdict).

## Assumptions

- The XRay plugin's overlay, control deck, `@XRayMock` scaffolder, and scenario YAML exist and parse; this feature wires them to the ledger and the dependency-mock rail (proving + completing, not reinventing).
- The ledger's declared sources are the quoted-literal contract and the Presentation/route contract row; dynamic UI composition is out of scope (never guessed).
- The merge-gate composition targets 074's conformance verdict; on hosts without 074, the gate still runs standalone (CI-able).
- ZikZak-narrow acceptance: the login feature's surfaces are the target corpus.
