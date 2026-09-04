# Traceability: 074-plugin-merge-contract

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:03edccc95de1df9810db1f3b847d1400ad8b5c3a487c9cb7bd55d4f707098bd9
statements: 21
automated: 21
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 32 | 1. **Given** a verified slice with declared routes, **When** merge lands it in the host, **Then** the host's route barrel is regenerated to include the feature's routes. | A1 | automated |
| AC-2 | 34 | 2. **Given** the landing, **When** each declared route path is resolved through the host's route table, **Then** it resolves to the feature's page. | A2 | automated |
| AC-3 | 36 | 3. **Given** the merged host, **When** a hand-edit comparison is taken against the pre-merge host, **Then** the only changes outside the feature's own artifacts are regenerated barrels (no manual wiring). | A3 | automated |
| AC-4 | 51 | 1. **Given** a verified slice with declared dependencies, **When** merge lands it, **Then** the feature's binding module registers through the host's locator in both mock and real flavors. | A4 | automated |
| AC-5 | 53 | 2. **Given** the merged host, **When** the DI-graph construction check runs, **Then** every token the feature declares resolves (the graph constructs fully). | A5 | automated |
| AC-6 | 55 | 3. **Given** the merged host booted in mock flavor, **When** the feature's page builds, **Then** every dependency touchpoint serves the certified mock. | A6 | automated |
| AC-7 | 70 | 1. **Given** a verified slice, **When** merge lands its views, **Then** each page composes behind the host's adaptive shell convention. | A7 | automated |
| AC-8 | 72 | 2. **Given** a slice whose view artifact bypasses the shell convention, **When** merge runs, **Then** it refuses naming the off-convention artifact. | A8 | automated |
| AC-9 | 87 | 1. **Given** a conforming slice, **When** merge completes, **Then** a machine-readable verdict reports routes/DI/feature-suite each passing and the host lands committed. | A9 | automated |
| AC-10 | 89 | 2. **Given** a slice whose route declaration was removed after verify, **When** merge runs, **Then** the routes check fails, the host is rolled back byte-identical to pre-merge, and the exit is non-zero naming the failed check. | A10 | automated |
| AC-11 | 91 | 3. **Given** a slice whose feature suite is red in-host, **When** merge runs, **Then** the feature-suite check fails, the host rolls back, and the failure names the red behavior. | A11 | automated |
| AC-12 | 93 | 4. **Given** any rolled-back merge, **When** the pre-merge and post-rollback host trees are compared, **Then** they are byte-identical. | A12 | automated |
| FR-001 | 109 | - **FR-001**: Merge MUST regenerate the host's route barrel to include the merged feature's routes; hand-edited host routing is never required and never performed. | U1 | automated |
| FR-002 | 110 | - **FR-002**: Every declared route path MUST resolve to the feature's page in the merged host (route-resolution check). | U2 | automated |
| FR-003 | 111 | - **FR-003**: Merge MUST register the feature's bindings through the host's service locator in mock and real flavors; the DI-graph construction check MUST construct the full graph in the merged host. | U3 | automated |
| FR-004 | 112 | - **FR-004**: Merged views MUST compose behind the host's adaptive shell convention; off-convention view artifacts MUST be refused naming the artifact. | U4 | automated |
| FR-005 | 113 | - **FR-005**: Merge MUST run the conformance suite (routes resolve, DI graph constructs, feature suite green in-host) after landing, producing a machine-readable verdict with one line per check. | U5 | automated |
| FR-006 | 114 | - **FR-006**: Any conformance failure MUST roll the host back byte-identical to its pre-merge state, exit non-zero, and name the failed checks. | U6 | automated |
| FR-007 | 115 | - **FR-007**: The feature-suite gate MUST compare against a pre-merge baseline: pre-existing reds never fail a merge; new reds always do. | U7 | automated |
| FR-008 | 116 | - **FR-008**: Merge MUST be idempotent — re-merging a merged feature changes nothing and re-runs the gates. | U8 | automated |
| FR-009 | 117 | - **FR-009**: Every refusal and every failed gate MUST name the offending artifact, token, or behavior with a `--> fix:` hint. | U9 | automated |

