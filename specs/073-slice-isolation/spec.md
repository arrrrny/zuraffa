# Feature Specification: Slice-Driven Isolation (prove the slice plugin end to end)

**Feature Branch**: `073-slice-isolation`

**Created**: 2026-09-03

**Status**: Draft

**Template Version**: `zuraffa-1.0`

**Input**: User description: "https://github.com/arrrrny/zuraffa/issues/961 — [ZIKZAK-REBUILD] slice-driven isolation: prove the never-used slice plugin — cut login into a runnable sandbox, develop with the full tdd loop, merge back."

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| --- | --- | --- | --- |
| FirebaseAuth | service | signIn(email, password) -> User, signOut() -> void | P1 |
| GoRouterHost | service | routeFor(path) -> PageRoute | P1 |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - `slice cut` produces a runnable sandbox (Priority: P1)

A developer (or agent) cuts a feature slice from a host project: `zfa slice cut --feature <feature> --from <host>` produces a sandbox project that is runnable on its own — it carries the feature's spec and tdd artifacts, an app shell, a router harness exposing exactly the feature's routes, and DI wiring that binds the feature's certified mocks at every declared touchpoint. Running the feature's tests in the sandbox requires nothing from the host: no host imports, no whole-app suite, no boot of unrelated features.

**Why this priority**: Isolation is the product. Without a runnable sandbox the slice plugin is a file copy; with it, feature development never pays the whole-app suite tax and can never break unrelated features.

**Independent Test**: Can be fully tested by cutting a feature from a fixture host, running the sandbox's test suite (and a widget test that pumps the shell) without any host path present, and confirming green. Delivers: features develop in a world of their own.

**Acceptance Scenarios**:

1. **Given** a host project with a declared login feature, **When** `zfa slice cut --feature login --from <host>` runs, **Then** the sandbox contains the feature's spec, tdd artifacts, an app shell, a router harness exposing exactly the feature's routes, and DI wiring binding certified mocks for every declared dependency.
2. **Given** the sandbox with the host project made unavailable, **When** the sandbox's test suite runs, **Then** it is green — no test references the host.
3. **Given** the sandbox, **When** a widget test pumps the shell and navigates a declared route, **Then** the route resolves and renders through the mock DI bindings.
4. **Given** the feature declares a platform-channel dependency, **When** the sandbox is cut, **Then** the certified channel fake from the tdd plugin is installed in the sandbox's DI.
5. **Given** a second `slice cut` with unchanged inputs, **When** it completes, **Then** the sandbox's generated wiring is byte-for-byte identical (deterministic scaffolding).

---

### User Story 2 - The full tdd loop runs inside the sandbox (Priority: P2)

The tdd loop (plan, gen, verify-red, make, view, refactor) runs against the sandbox as its project root: behaviors derive from the slice's spec, reds certify, greens land, and the cycle journal and artifact registry the loop writes travel with the sandbox. An agent with no knowledge of the host app beyond the spec can develop the feature end to end inside the sandbox.

**Why this priority**: The loop is the development machine; if it cannot run in the sandbox, isolation is cosmetic. Journals that travel are what make the eventual merge auditable.

**Independent Test**: Can be fully tested by driving `zfa tdd run <feature>` with the sandbox as project root for a spec with behaviors, then confirming the loop completes and the journal/registry live inside the sandbox. Delivers: a feature developed entirely in isolation, with receipts.

**Acceptance Scenarios**:

1. **Given** a sandbox carrying a feature spec with behaviors, **When** `zfa tdd run <feature>` runs with the sandbox as project root, **Then** the loop completes its cycle over those behaviors (red certified, green landed) with no reference to the host.
2. **Given** the completed loop run, **When** the sandbox's tdd journal and registry are read, **Then** they contain the run's evidence (reds certified, greens, artifacts) — the receipts live in the sandbox, not the host.
3. **Given** an operator whose only input is the spec, **When** they drive the loop in the sandbox, **Then** every step succeeds without host knowledge.

---

### User Story 3 - `slice verify` certifies self-containment (Priority: P3)

`zfa slice verify` checks the cut is what it claims: self-containment (no references into the host), mock certification (every declared dependency touchpoint binds a certified mock), and suite state (the sandbox suite is green). The verdict is machine-readable JSON on stdout with a non-zero exit when any check fails, naming the failing check and the offending references.

**Why this priority**: Verification is what makes the sandbox trustworthy before its artifacts merge; without it, "isolation" is unproven assertion and merge inherits silent host coupling.

**Independent Test**: Can be fully tested by verifying a clean sandbox (exit 0, JSON verdict with all checks passing), then re-verifying after deliberately introducing a host import (exit non-zero, the import named). Delivers: a one-command trust check for any slice.

**Acceptance Scenarios**:

1. **Given** a clean sandbox, **When** `zfa slice verify` runs, **Then** it exits 0 and the JSON verdict reports self-containment, mock certification, and suite state as passing.
2. **Given** a sandbox file that imports a host-only path, **When** verify runs, **Then** it exits non-zero, its verdict marks self-containment failed, and the offending reference is named.
3. **Given** a sandbox whose declared dependency lacks a certified mock binding, **When** verify runs, **Then** mock certification fails naming the unbound dependency.

---

### User Story 4 - `slice merge` lands the feature back (Priority: P4)

`zfa slice merge --into <host>` lands the sandbox-developed feature into the host: the feature's generated artifacts, journal, and registry travel with it, and the HOST suite runs green after the landing. This is the mechanical landing of a proven slice; the deeper plug-in contract (route registration, DI conformance gates inside the host) is feature 074's scope.

**Why this priority**: A slice that cannot come home is a dead end. Landing plus host-suite green closes the isolation loop; the conformance contract is a separate, later hardening.

**Independent Test**: Can be fully tested by merging a verified sandbox into a fixture host and confirming the feature's artifacts land and the host suite is green afterwards. Delivers: isolation that ends in a landing, not a fork.

**Acceptance Scenarios**:

1. **Given** a verified sandbox, **When** `zfa slice merge --into <host>` runs, **Then** the feature's artifacts, journal, and registry land in the host.
2. **Given** the landing, **When** the host's suite runs, **Then** it is green.
3. **Given** an unverified sandbox (verify failing), **When** merge runs, **Then** it refuses naming the failed check (merge requires a verified slice).

---

### Edge Cases

- What happens when the host path does not exist or is not a zfa project? `cut` refuses naming the path and the missing project marker.
- What happens when the feature has no spec in the host? `cut` refuses — a slice without its spec cannot drive the loop.
- What happens when a sandbox file references the host after cut? `verify` fails self-containment naming the reference; `merge` refuses on the failed verify.
- What happens when merge finds existing host artifacts for the feature? It overwrites deterministically and surfaces the overwrite, or refuses with `--force` absent (mirroring generator force conventions).
- What happens when the sandbox suite is red at verify time? Suite state fails in the verdict; merge refuses.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `zfa slice cut --feature <f> --from <host>` MUST produce a sandbox project carrying the feature's spec, tdd artifacts, a runnable app shell, a router harness exposing exactly the feature's declared routes, and DI wiring binding certified mocks for every declared dependency touchpoint.
- **FR-002**: The sandbox MUST be self-contained: its suite runs green with the host unavailable, and no generated file references the host.
- **FR-003**: The tdd loop MUST run with the sandbox as project root, and its journal/registry evidence MUST live inside the sandbox.
- **FR-004**: `zfa slice verify` MUST emit a machine-readable JSON verdict covering self-containment, mock certification, and suite state, exiting non-zero and naming the failing check and offending references on failure.
- **FR-005**: `zfa slice merge --into <host>` MUST land the feature's artifacts, journal, and registry into the host and MUST refuse when verify's verdict is failing or absent.
- **FR-006**: After merge, the HOST suite MUST run green; merge reports the host-suite outcome.
- **FR-007**: Cut scaffolding MUST be deterministic: unchanged inputs produce byte-identical wiring.
- **FR-008**: Every refusal across cut/verify/merge MUST name the offending path, reference, or check with a `--> fix:` hint.

### Key Entities *(include if feature involves data)*

- **Slice**: the sandbox project for one feature — spec + tdd artifacts + shell + router harness + mock DI wiring + journal/registry.
- **SliceManifest**: the cut's declared facts (feature, host, routes, dependency bindings, artifact inventory) — what verify checks and what merge lands.
- **SliceVerdict**: verify's machine-readable result (per-check pass/fail + offending references).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A login-shaped feature cut from a fixture host yields a sandbox whose suite is green with the host path unavailable, including a shell-pumping widget test navigating a declared route on certified mocks.
- **SC-002**: `zfa tdd run <feature>` completes inside the sandbox with journal and registry evidence written in the sandbox.
- **SC-003**: `zfa slice verify` passes clean (exit 0) and catches each seeded defect (host import, unbound dependency, red suite) with the offender named (exit non-zero).
- **SC-004**: Merge lands the feature into the fixture host with the host suite green afterwards; an unverified sandbox refuses.
- **SC-005**: Two identical cuts produce byte-identical wiring.

## Assumptions

- Proving "runnable" here means the sandbox's TEST suite (including widget tests pumping the shell on certified mocks) runs standalone; booting a native desktop window (`flutter run -d macos`) is an operator-level check outside CI's reach and is not an automated gate.
- The host for acceptance is a fixture project exercising the plugin; the real ZikZak app is the reporter's environment.
- The slice plugin's cut/export/merge/verify capabilities exist; this feature proves them end to end and completes the missing runnable-sandbox, verify-verdict, and journal-travel pieces (no parallel plugin).
- The deeper host plug-in contract (route barrel registration, DI conformance gate inside the host) is feature 074's scope; 073's merge stops at landing + host suite green.
