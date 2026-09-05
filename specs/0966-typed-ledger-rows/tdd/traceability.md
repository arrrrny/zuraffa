# Traceability: 0966-typed-ledger-rows

Coverage proof for spec 0966 (issue #966): every FR/AC statement maps to a behavior
row. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan
required).

<!-- tdd:traceability
spec-hash: sha256:44699e1163577e29718fc01c43a804c020c062b49b4d17673069533dd987162a
statements: 18
automated: 18
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 37 | 1. **Given** a login-shaped feature whose plan declares the 9 production literals plus absence and sequence scenarios, **When** a ledger is derived where only the 9 presence rows are proven green (the all-9-literals-`Column` view), **Then** the coverage gate fails and names the untraced kinds — absence and sequence — as gaps. | T1 | automated |
| AC-2 | 38 | 2. **Given** the same feature with an honest ledger where an absence row is traced by a green behavior asserting the error banner hidden in the initial state, **When** the gate runs, **Then** the absence row reads DONE and the absence kind is no longer a gap. | T2 | automated |
| AC-3 | 39 | 3. **Given** a sequence row declared for the chain tap → loading → resolve → navigate, **When** a green behavior traces the chain end-to-end, **Then** the sequence row reads DONE with the chain named. | T3 | automated |
| AC-4 | 40 | 4. **Given** a state row declared for "buttons disabled while in flight" (an FR-005-class behavior), **When** a green behavior asserts the disabled attribute in the in-flight state, **Then** the state row reads DONE — FR-005-class behaviors are expressible and traced end-to-end in 004-login-ui. | T4 | automated |
| AC-5 | 44 | 1. **Given** a scenario description carrying an absence verb ("hidden", "not shown", "does not render"), **When** the plan derives its ledger row, **Then** the row's kind is absence — never flattened to presence. | T1 | automated |
| AC-6 | 45 | 2. **Given** a scenario carrying a navigation verb ("navigates to", "routes to"), **When** the plan derives its ledger row, **Then** the row's kind is navigation. | T6 | automated |
| AC-7 | 46 | 3. **Given** a scenario carrying an attribute verb ("disabled", "enabled") without an interaction chain, **When** the plan derives its ledger row, **Then** the row's kind is state. | T4 | automated |
| AC-8 | 47 | 4. **Given** a scenario describing an interaction chain (tap → loading → resolve), **When** the plan derives its ledger row, **Then** the row's kind is sequence with the chain steps recorded. | T3 | automated |
| AC-9 | 51 | 1. **Given** a screen whose ledger holds presence rows only, **When** the XRay overlay renders the screen, **Then** it distinguishes kind coverage per screen — presence complete, absence/sequence untraced — and the screen shows as partially traced. | T5 | automated |
| AC-10 | 52 | 2. **Given** the deck, **When** it lists a screen's kind coverage, **Then** every declared kind appears with its traced/total counts and untraced kinds are named. | T5 | automated |
| AC-11 | 56 | 1. **Given** a golden row (visual-snapshot surface) declared with per-platform tolerance, **When** the gate evaluates the ledger, **Then** the golden row is advisory — it never blocks the merge gate regardless of state, and the verdict records it as advisory (deliberate decision, recorded). | T6 | automated |
| FR-001 | 60 | - **FR-001**: Each ledger row MUST carry a kind — `presence`, `absence`, `navigation`, `state`, or `sequence` — and the coverage gate MUST treat a declared kind with no traced row as a gap (untraced kinds are gaps), naming the kind. | T1 | automated |
| FR-002 | 61 | - **FR-002**: An absence row MUST express "not rendered in state S" and MUST be traced (DONE) exactly when a green behavior asserts the surface hidden in that state (the error banner hidden initially is traced; a permanently rendered banner cannot satisfy it). | T2 | automated |
| FR-003 | 62 | - **FR-003**: A sequence row MUST record the interaction chain steps (e.g. tap → loading → resolve → navigate) and MUST be traced (DONE) exactly when a green behavior traces the chain end-to-end. | T3 | automated |
| FR-004 | 63 | - **FR-004**: A state row MUST record the asserted widget attribute (e.g. buttons disabled while in flight — FR-005-class) and MUST be traceable end-to-end in the 004-login-ui corpus. | T4 | automated |
| FR-005 | 64 | - **FR-005**: Ledger row kinds MUST be assigned at plan time from scenario verbs (composing with the finder-kind taxonomy #964): absence verbs yield absence rows, navigation verbs yield navigation rows, attribute verbs yield state rows, interaction chains yield sequence rows, and default render verbs yield presence rows — never inferred post hoc and never flattened to presence. | T1, T4, T6, T7 | automated |
| FR-006 | 65 | - **FR-006**: The XRay overlay MUST render kind coverage per screen — every declared kind with its traced/total counts — so a screen with presence-only rows shows as partially traced; untraced kinds are highlighted, never painted as proof. | T5, T8 | automated |
| FR-007 | 66 | - **FR-007**: Golden rows MUST be advisory with per-platform tolerance: they are excluded from the merge-gate verdict (recorded decision — flaky economics on slow CI) and reported separately as advisory in the verdict and the deck. | T6 | automated |
