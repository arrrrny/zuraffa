# Traceability: 075-ui-coverage-ledger

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:6705474b0ba98113bbd3bc34488e7cef2b8de668e47150f2b7c53d557f5d3c5f
statements: 22
automated: 22
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 31 | 1. **Given** a spec whose scenarios quote 8 production strings, declare a route row, and name 3 button affordances, **When** the plan runs, **Then** the ledger contains one row per surface with kind text/route/affordance. | A1 | automated |
| AC-2 | 32 | 2. **Given** the produced ledger, **When** a surface's proving behaviors are green, **Then** its state reads DONE with the proving behavior ids named. | A2 | automated |
| AC-3 | 33 | 3. **Given** a surface no behavior traces to, **When** the plan runs, **Then** the row exists with an empty prover and a state marking it unproven — visible at plan time, not after merge. | A3 | automated |
| AC-4 | 34 | 4. **Given** a scenario quoted literal that names no production surface (an example value), **When** the plan runs, **Then** it is not forced into the ledger (the ledger's source is the declared Presentation/route contract plus scenario surface markers, not every quotation). | A4 | automated |
| AC-5 | 48 | 1. **Given** a ledger where every row is proven by a green behavior, **When** the coverage gate runs, **Then** it exits 0 with a JSON verdict listing each surface proven. | A5 | automated |
| AC-6 | 49 | 2. **Given** a ledger with one unproven affordance, **When** the gate runs, **Then** it exits non-zero and the verdict names the surface and its missing prover. | A6 | automated |
| AC-7 | 50 | 3. **Given** the gate wired into merge, **When** a feature with an incomplete ledger lands, **Then** merge is blocked with the gap named. | A7 | automated |
| AC-8 | 51 | 4. **Given** a behavior that is planned but not green, **When** the gate runs, **Then** the surfaces it would prove read NOT-DONE (green is the only proof). | A8 | automated |
| AC-9 | 65 | 1. **Given** a harness app with the login ledger seeded (one unproven affordance), **When** xray is enabled and the app renders, **Then** the overlay highlights exactly the unproven affordance and paints proven surfaces clean. | A9 | automated |
| AC-10 | 66 | 2. **Given** the overlay, **When** a surface's ledger state changes to proven, **Then** the overlay reflects the new state on the next paint. | A10 | automated |
| AC-11 | 67 | 3. **Given** the control deck, **When** opened, **Then** it lists the ledger rows with their states (the deck drives the ledger, not a separate inventory). | A11 | automated |
| AC-12 | 81 | 1. **Given** a feature with generated dependency mocks (072), **When** the xray mock scaffolder runs, **Then** the deck lists each touchpoint with drive-able scenario entries. | A12 | automated |
| AC-13 | 82 | 2. **Given** the deck driving a touchpoint, **When** a scenario is selected, **Then** the certified fake serves the scripted responses (the demo runs on the certification, not a parallel fake). | A13 | automated |
| AC-14 | 83 | 3. **Given** a touchpoint with no generated mock, **When** the scaffolder runs, **Then** it names `zfa mock dependency <Name>` as the fix — no hand-authored stand-ins. | A14 | automated |
| FR-001 | 99 | - **FR-001**: The plan MUST produce a per-feature UI surface ledger enumerating declared surfaces — static texts (quoted-literal contract), declared routes (Presentation contract row), and named affordances — each with kind, proving behavior ids, and state. | U1 | automated |
| FR-002 | 100 | - **FR-002**: A surface with no tracing behavior MUST appear in the ledger as unproven at plan time (visible, never omitted). | U2 | automated |
| FR-003 | 101 | - **FR-003**: Ledger state MUST derive from current evidence: a surface is DONE only when at least one of its provers is green; planned-but-red provers never count. | U3 | automated |
| FR-004 | 102 | - **FR-004**: `zfa tdd coverage` (the coverage gate) MUST emit a machine-readable JSON verdict (one line per surface: kind, proven-by, state) and exit 0 only when every row is DONE; failures name each unproven surface and its missing prover. | U4 | automated |
| FR-005 | 103 | - **FR-005**: The coverage gate MUST be wireable as a merge/landing gate: an incomplete ledger blocks the landing naming the gaps (composing with the conformance verdict of 074). | U5 | automated |
| FR-006 | 104 | - **FR-006**: With xray enabled, the overlay MUST paint surfaces by ledger state (proven clean, unproven highlighted), reading the ledger as its source of truth; with no ledger present it MUST report absence, never paint proof. | U6 | automated |
| FR-007 | 105 | - **FR-007**: The control deck MUST list ledger rows with states, and the xray mock scaffolder MUST wire to 072's dependency mocks so deck entries exist without hand authoring; a missing mock names the generation fix. | U7 | automated |
| FR-008 | 106 | - **FR-008**: Every refusal and gate failure MUST name the surface, the ledger row, or the missing artifact with a `--> fix:` hint. | U8 | automated |

