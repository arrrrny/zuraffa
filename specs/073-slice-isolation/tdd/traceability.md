# Traceability: 073-slice-isolation

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:89d429ec2ebd2750a623ea3f1e76f25a409777b66933e69a8796f5851ac5bac4
statements: 22
automated: 22
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 32 | 1. **Given** a host project with a declared login feature, **When** `zfa slice cut --feature login --from <host>` runs, **Then** the sandbox contains the feature's spec, tdd artifacts, an app shell, a router harness exposing exactly the feature's routes, and DI wiring binding certified mocks for every declared dependency. | A1 | automated |
| AC-2 | 34 | 2. **Given** the sandbox with the host project made unavailable, **When** the sandbox's test suite runs, **Then** it is green — no test references the host. | A2 | automated |
| AC-3 | 36 | 3. **Given** the sandbox, **When** a widget test pumps the shell and navigates a declared route, **Then** the route resolves and renders through the mock DI bindings. | A3 | automated |
| AC-4 | 38 | 4. **Given** the feature declares a platform-channel dependency, **When** the sandbox is cut, **Then** the certified channel fake from the tdd plugin is installed in the sandbox's DI. | A4 | automated |
| AC-5 | 40 | 5. **Given** a second `slice cut` with unchanged inputs, **When** it completes, **Then** the sandbox's generated wiring is byte-for-byte identical (deterministic scaffolding). | A5 | automated |
| AC-6 | 55 | 1. **Given** a sandbox carrying a feature spec with behaviors, **When** `zfa tdd run <feature>` runs with the sandbox as project root, **Then** the loop completes its cycle over those behaviors (red certified, green landed) with no reference to the host. | A6 | automated |
| AC-7 | 57 | 2. **Given** the completed loop run, **When** the sandbox's tdd journal and registry are read, **Then** they contain the run's evidence (reds certified, greens, artifacts) — the receipts live in the sandbox, not the host. | A7 | automated |
| AC-8 | 59 | 3. **Given** an operator whose only input is the spec, **When** they drive the loop in the sandbox, **Then** every step succeeds without host knowledge. | A8 | automated |
| AC-9 | 74 | 1. **Given** a clean sandbox, **When** `zfa slice verify` runs, **Then** it exits 0 and the JSON verdict reports self-containment, mock certification, and suite state as passing. | A9 | automated |
| AC-10 | 76 | 2. **Given** a sandbox file that imports a host-only path, **When** verify runs, **Then** it exits non-zero, its verdict marks self-containment failed, and the offending reference is named. | A10 | automated |
| AC-11 | 78 | 3. **Given** a sandbox whose declared dependency lacks a certified mock binding, **When** verify runs, **Then** mock certification fails naming the unbound dependency. | A11 | automated |
| AC-12 | 93 | 1. **Given** a verified sandbox, **When** `zfa slice merge --into <host>` runs, **Then** the feature's artifacts, journal, and registry land in the host. | A12 | automated |
| AC-13 | 95 | 2. **Given** the landing, **When** the host's suite runs, **Then** it is green. | A13 | automated |
| AC-14 | 97 | 3. **Given** an unverified sandbox (verify failing), **When** merge runs, **Then** it refuses naming the failed check (merge requires a verified slice). | A14 | automated |
| FR-001 | 114 | - **FR-001**: `zfa slice cut --feature <f> --from <host>` MUST produce a sandbox project carrying the feature's spec, tdd artifacts, a runnable app shell, a router harness exposing exactly the feature's declared routes, and DI wiring binding certified mocks for every declared dependency touchpoint. | U1 | automated |
| FR-002 | 115 | - **FR-002**: The sandbox MUST be self-contained: its suite runs green with the host unavailable, and no generated file references the host. | U2 | automated |
| FR-003 | 116 | - **FR-003**: The tdd loop MUST run with the sandbox as project root, and its journal/registry evidence MUST live inside the sandbox. | U3 | automated |
| FR-004 | 117 | - **FR-004**: `zfa slice verify` MUST emit a machine-readable JSON verdict covering self-containment, mock certification, and suite state, exiting non-zero and naming the failing check and offending references on failure. | U4 | automated |
| FR-005 | 118 | - **FR-005**: `zfa slice merge --into <host>` MUST land the feature's artifacts, journal, and registry into the host and MUST refuse when verify's verdict is failing or absent. | U5 | automated |
| FR-006 | 119 | - **FR-006**: After merge, the HOST suite MUST run green; merge reports the host-suite outcome. | U6 | automated |
| FR-007 | 120 | - **FR-007**: Cut scaffolding MUST be deterministic: unchanged inputs produce byte-identical wiring. | U7 | automated |
| FR-008 | 121 | - **FR-008**: Every refusal across cut/verify/merge MUST name the offending path, reference, or check with a `--> fix:` hint. | U8 | automated |

