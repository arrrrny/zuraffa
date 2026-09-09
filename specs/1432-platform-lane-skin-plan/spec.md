# Feature Specification: Platform-typed acceptance scenarios are first-class SKIN lane rows

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `1432-platform-lane-skin-plan`

**Created**: 2026-09-09

**Status**: Draft

**Input**: User description: "Issue #1432 — TDD: lane-split silently drops acceptance scenarios typed `platform` from the SKIN plan table — route log says 'platform lane', table omits the row, run reports lane green without them"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every routed behavior renders as a lane row (Priority: P1)

A developer declares acceptance scenarios in a zuraffa-1.0 spec using any of the
template's declared kinds and plans the feature with the lane split. Every
behavior the planner routes to a lane appears as a row in that lane's plan
artifact — the route log and the artifact never disagree. Today a scenario
typed `platform` is routed to the skin lane in the log ("route: A1 -> platform
lane") while the emitted SKIN plan table omits it, so the lane reports green
with spec-derived acceptance behaviors silently untested.

**Why this priority**: This is the silent-drop itself — the coverage gate reads
green while the spec's own acceptance contract is untested. Every other
quality gate downstream trusts the lane artifact to be complete.

**Independent Test**: Plan a spec whose SKIN lane declares an
acceptance-typed scenario and a platform-typed acceptance scenario; the SKIN
artifact's outer-loop table carries both rows and the plan exits 0.

**Acceptance Scenarios**:

1. **Given** a zuraffa-1.0 spec whose Lanes section declares behaviors A1–A8
   in the SKIN lane, where A1 is typed `platform` and A6–A8 are typed
   `acceptance`, **When** the feature is planned with the lane split,
   **Then** the SKIN plan artifact's outer-loop table carries a row for A1
   with the same columns as the A6–A8 acceptance rows, and the plan exits 0
   **Type**: acceptance
2. **Given** a planned lane-split feature, **When** the plan's route log
   routes any behavior id to a lane, **Then** that id appears as a row in the
   corresponding lane artifact — for every routed id, without exception
   **Type**: acceptance

---

### User Story 2 - Refuse instead of dropping (errors-are-an-API) (Priority: P2)

If the planner cannot represent a routed behavior kind in a lane table, it
must refuse loudly instead of exiting 0 with the row missing. A refusal names
the behavior id, its kind, and the spec line of the routing declaration, and
prescribes the remedy. Today the drop is silent: exit 0, route log claims the
lane, artifact omits the row.

**Why this priority**: Errors-are-an-API is the repo's stated contract for
recovery: a refusal can be acted on; a silent drop corrupts every downstream
gate while reporting green.

**Independent Test**: Plan a spec that routes a behavior of a kind the lane
table cannot carry; the plan exits non-zero naming the behavior id and kind,
and no lane artifact is emitted claiming coverage of that behavior.

**Acceptance Scenarios**:

1. **Given** a spec routing a behavior whose typed kind cannot be rendered
   into its lane's plan table, **When** the feature is planned, **Then** the
   plan exits non-zero with a refusal naming the behavior id, the kind, and
   the declaration's spec line — never exit 0 with the row absent
   **Type**: acceptance

---

### User Story 3 - Lane accounting stays honest (Priority: P3)

A lane plan's rendered behavior counts are derived from the rows its artifact
carries — never from a larger internal set. The lane meta-index, the lane
artifact's row count, and the plan's summary agree, so a downstream run's
green report cannot exceed what the artifact actually declares.

**Why this priority**: Defense in depth: even with US1 fixed, counts derived
from inconsistent sources would re-introduce drift the next time a kind is
added.

**Independent Test**: Plan a lane-split spec; each lane's rendered declared
count equals the number of data rows in its artifact, including
platform-typed rows.

**Acceptance Scenarios**:

1. **Given** a planned lane-split feature whose SKIN lane holds acceptance-,
   widget-, and platform-typed behaviors, **When** the plan renders the
   lane's behavior summary, **Then** the declared count equals the number of
   rows the SKIN artifact carries and names every behavior id
   **Type**: acceptance

---

### Edge Cases

- What happens when a `platform`-typed behavior is declared in the CORE lane
  (pure Dart, flutter not allowed)? The plan must either refuse naming the
  lane conflict or place it explicitly — never drop it.
  **Type**: unit
- What happens when a behavior carries both a `Type: platform` marker and a
  `traces:` reference to a channel contract row (both resolve platform)?
  The agreeing declarations must not be read as a conflict.
  **Type**: unit
- What happens to widget-typed scenarios (the #830 UI-observable prose case)?
  Their rendering must be unchanged — a regression guard.
  **Type**: unit
- What happens when a spec declares a behavior in `## Lanes` but no scenario
  carries it? The existing undeclared/unresolvable refusal must keep firing
  (no new silent path).
  **Type**: unit

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The lane planner MUST render every spec-derived behavior it
  routes to a lane as a row in that lane's plan artifact — routing and
  rendering MUST agree for every routed behavior id
- **FR-002**: A scenario typed `platform` that routes to the SKIN lane MUST
  render as an outer-loop row with the same columns and run contract as
  acceptance-typed rows (flutter harness allowed)
- **FR-003**: The lane planner MUST refuse (non-zero exit naming the behavior
  id, its kind, and the declaration's spec line) any routed behavior whose
  kind it cannot render into a lane table — it MUST NOT exit 0 while omitting
  the row
- **FR-004**: Each lane's rendered declared-behavior count MUST equal the
  number of rows its artifact carries (counts derive from the rendered table,
  never from a larger internal set)
- **FR-005**: Existing renderings for acceptance- and widget-typed (issue
  #830) scenarios MUST be unchanged, and the existing refusal for undeclared
  or unresolvable behaviors MUST keep firing

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A SKIN lane declaring 8 acceptance-class behaviors of mixed
  `acceptance`/`platform` types plans to an artifact carrying exactly 8
  outer-loop rows (today: 3, with 5 dropped)
- **SC-002**: For every behavior id in the plan's route log, the
  corresponding lane artifact contains a row with that id — zero
  routed-but-absent ids
- **SC-003**: A plan that cannot render a routed kind exits non-zero with a
  refusal naming the id, kind, and spec line in 100% of such cases
- **SC-004**: Each lane artifact's rendered declared count equals its actual
  data-row count on every lane-split plan

## Assumptions

- The declared scenario kinds remain the zuraffa-1.0 template's set
  (acceptance, widget, unit, theme, ffi, platform — issue #1186)
- A `platform`-typed scenario exercises the platform harness, so its lane is
  the SKIN lane (flutter allowed) — matching what the route log already
  claims today
- Errors-are-an-API: a refusal naming the offending declaration is the
  correct alternative when a kind cannot be rendered; silent omission is
  never acceptable
- Scope is the lane-split plan path (the split artifacts and their counts);
  the single-file (non-lane) plan path is unchanged
- Sibling issue #1419 (contract rows dropped from lane plans) is a different
  trigger of the same silent-drop class; this spec fixes the platform-typed
  trigger without regressing the #1419 contract-path work already on master
