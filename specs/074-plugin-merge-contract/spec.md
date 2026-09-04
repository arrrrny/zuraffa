# Feature Specification: Plug-In Merge Contract (a slice lands in the host with zero hand-edits)

**Feature Branch**: `074-plugin-merge-contract`

**Created**: 2026-09-03

**Status**: Draft

**Template Version**: `zuraffa-1.0`

**Input**: User description: "https://github.com/arrrrny/zuraffa/issues/962 — [ZIKZAK-REBUILD] plug-in contract: merge lands a feature in zik_zak with zero hand-edits — routes register, DI resolves, conformance-gated."

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| --- | --- | --- | --- |
| HostRouter | service | routes() -> List, register(route) -> void | P1 |
| HostDI | service | bind(token, factory) -> void, resolve(token) -> Object | P1 |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Merge registers the feature's routes in the host (Priority: P1)

When a verified slice merges into the host, the feature's routes become live through the host's route-generation barrel: the barrel regenerates to include the merged feature's route table, so navigating to the feature's paths resolves in the host with no hand-edit of the host router. An operator can verify registration mechanically — the barrel lists the feature's routes after merge.

**Why this priority**: Routes are the feature's front door. A merge that leaves `/login` unreachable is not a plug-in; it is loose files. The route barrel is the existing regeneration seam, so the contract is: merge regenerates it, never edits it by hand.

**Independent Test**: Can be fully tested by merging a slice with declared routes into a fixture host and confirming the regenerated route barrel exposes the feature's routes and a route-resolution check resolves each declared path. Delivers: features whose front doors open on arrival.

**Acceptance Scenarios**:

1. **Given** a verified slice with declared routes, **When** merge lands it in the host, **Then** the host's route barrel is regenerated to include the feature's routes.
   **Type**: acceptance
2. **Given** the landing, **When** each declared route path is resolved through the host's route table, **Then** it resolves to the feature's page.
   **Type**: acceptance
3. **Given** the merged host, **When** a hand-edit comparison is taken against the pre-merge host, **Then** the only changes outside the feature's own artifacts are regenerated barrels (no manual wiring).
   **Type**: acceptance

---

### User Story 2 - Merge binds the feature's DI through the host's locator (Priority: P2)

The merged feature's dependencies resolve through the host's service locator: the feature's binding module registers its factories (simulation/mock flavors per the flavor-switched DI machinery), and a DI-graph construction check — the existing bootstrap smoke pattern — constructs the full graph in the merged host without missing bindings.

**Why this priority**: Routes resolve pages; pages resolve dependencies. If the DI graph cannot construct the merged feature, the app boots into a crash. The graph check turns "should resolve" into a gate.

**Independent Test**: Can be fully tested by merging a slice and running a DI-graph construction check in the host that resolves every feature binding (mock and real flavors), confirming zero missing bindings. Delivers: features whose wiring is proven, not assumed.

**Acceptance Scenarios**:

1. **Given** a verified slice with declared dependencies, **When** merge lands it, **Then** the feature's binding module registers through the host's locator in both mock and real flavors.
   **Type**: acceptance
2. **Given** the merged host, **When** the DI-graph construction check runs, **Then** every token the feature declares resolves (the graph constructs fully).
   **Type**: acceptance
3. **Given** the merged host booted in mock flavor, **When** the feature's page builds, **Then** every dependency touchpoint serves the certified mock.
   **Type**: acceptance

---

### User Story 3 - Views compose behind the host's adaptive shell (Priority: P3)

The merged feature's pages land in the host's presentation layer composing behind the host's adaptive shell convention — the same view/presenter/controller skeleton the host already uses — so the feature's UI is indistinguishable in structure from the host's own features. Merge refuses view artifacts that bypass the shell convention (bare scaffolds, hand-rolled entrypoints).

**Why this priority**: Plug-in means the feature looks like it grew in the host. Views that bypass the shell create a second UI architecture inside one app.

**Independent Test**: Can be fully tested by merging a slice and checking each merged page composes the host's shell convention (a structural check against the view contract), and that a deliberately off-convention view artifact is refused. Delivers: features that fit the host's idiom.

**Acceptance Scenarios**:

1. **Given** a verified slice, **When** merge lands its views, **Then** each page composes behind the host's adaptive shell convention.
   **Type**: acceptance
2. **Given** a slice whose view artifact bypasses the shell convention, **When** merge runs, **Then** it refuses naming the off-convention artifact.
   **Type**: acceptance

---

### User Story 4 - Merge is conformance-gated: exit 0 or named-broken rollback (Priority: P4)

After landing, merge runs the conformance suite: routes resolve (US1), the DI graph constructs (US2), and the feature's suite runs green inside the host. All three pass → merge commits with a verdict naming each check. Any failure → merge rolls the host back to its pre-merge state and exits non-zero with the failed checks named. Verdicts, never prose.

**Why this priority**: The gate is what makes "zero hand-edits" a guarantee instead of a hope: a merge that cannot prove itself un-does itself.

**Independent Test**: Can be fully tested by merging a conforming slice (all checks pass, verdict green, host committed) and a sabotaged slice (route declaration removed → merge fails, host rolled back byte-identical, failures named). Delivers: merges that are their own proof.

**Acceptance Scenarios**:

1. **Given** a conforming slice, **When** merge completes, **Then** a machine-readable verdict reports routes/DI/feature-suite each passing and the host lands committed.
   **Type**: acceptance
2. **Given** a slice whose route declaration was removed after verify, **When** merge runs, **Then** the routes check fails, the host is rolled back byte-identical to pre-merge, and the exit is non-zero naming the failed check.
   **Type**: acceptance
3. **Given** a slice whose feature suite is red in-host, **When** merge runs, **Then** the feature-suite check fails, the host rolls back, and the failure names the red behavior.
   **Type**: acceptance
4. **Given** any rolled-back merge, **When** the pre-merge and post-rollback host trees are compared, **Then** they are byte-identical.
   **Type**: acceptance

---

### Edge Cases

- What happens when the host's route barrel has been hand-edited so regeneration would clobber manual routes? Regeneration is additive per the barrel's own convention; a conflicting route name refuses naming both.
- What happens when the feature declares a dependency the host cannot bind (missing flavor)? The DI-graph check fails at gate time naming the token; merge rolls back.
- What happens when merge runs on an already-merged feature? It is idempotent: regenerating barrels and re-running gates is safe; a second merge changes nothing.
- What happens when the host suite has pre-existing reds before merge? The baseline is captured pre-merge (the #741/#953 pattern); the gate compares post-merge against the baseline — pre-existing reds do not fail the merge, new reds do.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Merge MUST regenerate the host's route barrel to include the merged feature's routes; hand-edited host routing is never required and never performed.
- **FR-002**: Every declared route path MUST resolve to the feature's page in the merged host (route-resolution check).
- **FR-003**: Merge MUST register the feature's bindings through the host's service locator in mock and real flavors; the DI-graph construction check MUST construct the full graph in the merged host.
- **FR-004**: Merged views MUST compose behind the host's adaptive shell convention; off-convention view artifacts MUST be refused naming the artifact.
- **FR-005**: Merge MUST run the conformance suite (routes resolve, DI graph constructs, feature suite green in-host) after landing, producing a machine-readable verdict with one line per check.
- **FR-006**: Any conformance failure MUST roll the host back byte-identical to its pre-merge state, exit non-zero, and name the failed checks.
- **FR-007**: The feature-suite gate MUST compare against a pre-merge baseline: pre-existing reds never fail a merge; new reds always do.
- **FR-008**: Merge MUST be idempotent — re-merging a merged feature changes nothing and re-runs the gates.
- **FR-009**: Every refusal and every failed gate MUST name the offending artifact, token, or behavior with a `--> fix:` hint.

### Key Entities *(include if feature involves data)*

- **MergeContract**: the declared facts a landing must satisfy — feature routes, binding tokens (per flavor), view-convention conformance, suite command.
- **ConformanceVerdict**: machine-readable per-check result (routes/DI/feature-suite), the merge's exit proof.
- **HostBaseline**: the pre-merge host tree snapshot (byte-level) driving rollback and the new-red comparison.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A login-shaped verified slice merges into a fixture host with zero hand-edits: the route resolves, the DI graph constructs in both flavors, and the feature suite is green in-host (the whole rebuild acceptance, host-narrow).
- **SC-002**: Each sabotage case (route removed, binding missing, view off-convention, new red introduced) rolls the host back byte-identical and exits non-zero naming the failed check.
- **SC-003**: The conformance verdict reports one line per check and is parseable by the CI referee.
- **SC-004**: Re-merging a merged feature is a no-op with all gates re-passing.

## Assumptions

- The host's route barrel regeneration and flavor-switched DI machinery exist (#893/#934, `zfa route`); this feature wires merge to them, it does not reinvent them.
- The host-side suite and DI smoke patterns exist (bootstrap smoke); the gate reuses them.
- The host for acceptance is a fixture project; `~/Developer/zik_zak` is the reporter's environment.
- Slice verify (073) is the precondition: merge only lands verified slices.
