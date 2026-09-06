**Template Version**: `zuraffa-1.0`

# Spec 1004 — Skin contract slots: adaptive-layout platform matrix in spec

GitHub issue: arrrrny/zuraffa#1004

## Problem

The skin (views/widgets/routes/states) must have a **declared
contract** that the loop can referee. Today `zfa tdd plan` has no skin
contract: the widget lane invents finders from scenario literals
(#964), the `## Lanes` adaptive_slots render as a bare slot list
(#1000), and the 004-login-ui spec's skin surface is described by a
prose token/value table — nothing machine-parseable. This spec
formalizes what a skin contract IS and what `zfa tdd plan` emits for
it.

## Design

The contract is a DECLARATION: a `## Skin Contract` section authored
as a yaml block, parsed into a typed model
(`lib/src/skin/contract/adaptive_skin_contract.dart`) whose schema is
GENERATED from the model — never hand-maintained. `zfa tdd plan`
renders it into `tdd/04-SKIN.md` as typed rows plus a fenced JSON
contract block:

- **Platform contract** — one row per adaptive platform: the
  renders-the-slots statement, the per-platform overrides
  (`home_indicator_safe_area: required`, `title_bar_alignment:
  trailing`), the skin-lane behaviors the row contracts, and the
  declaration source.
- **State machine contract** — the happy-path chain
  (`initial -> loading -> data`) plus the alternate states
  (`error`, `empty`), one row per declared state.
- **Route contract** — one row per declared route: navigation target,
  derived screen class (`deal_list` -> `DealListScreen`), route path
  (`/deal_list`).
- **Skin contract (machine)** — the `toJson()` of the typed model in a
  fenced `json` block: the machine-parseable contract, validated
  against the generated JSON Schema (draft 2020-12) in tests.

Refusals (errors are an API, exit 2, no artifacts): an unknown key, a
duplicate key, a missing key, a platform override for an undeclared
slot, a `## Skin Contract` without `## Lanes` (the contract rides the
SKIN lane), and adaptive_slots drift between the contract and the SKIN
lane. The json-fenced skin-contract.v1 form (issue #1164) stays on its
own path: one section, one form, never a guess.

## Acceptance Scenarios

1. **Given** a spec declaring `## Skin Contract` with `adaptive_slots`, `platform_overrides`, `states`, and `routes`, **When** `zfa tdd plan <feature>` runs, **Then** `tdd/04-SKIN.md` carries the platform-contract rows, the state-machine rows, and the route-contract rows.
2. **Given** the emitted `04-SKIN.md`, **When** the fenced JSON block is extracted and parsed, **Then** the contract is JSON-parseable and validates against the generated JSON Schema.
3. **Given** a spec whose Skin Contract drifts (an unknown key, no `## Lanes`, or adaptive_slots disagreeing with the SKIN lane), **When** `zfa tdd plan <feature>` runs, **Then** the plan refuses with exit 2 naming the drift and writes no artifacts.

## Functional Requirements

- **FR-001**: The system shall parse the spec's `## Skin Contract` yaml section into the typed adaptive contract (adaptive_slots, platform_overrides, states, routes), refusing unknown, duplicate, or missing keys by name.
- **FR-002**: The system shall render the platform matrix rows, the state-machine rows, and the route rows into `tdd/04-SKIN.md`, tied to the skin-lane behaviors.
- **FR-003**: The system shall emit the machine JSON contract block generated from the typed model and validate it against the model-generated JSON Schema in tests.

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, A2, A3, U1, U2, U3]
    flutter_allowed: false
  - lane: SKIN
    behaviors: []
    flutter_allowed: true
    adaptive_slots: [mobile, ios, android, macos]
```

## Skin Contract

```yaml
Skin Contract:
  adaptive_slots: [mobile, ios, android, macos]
  platform_overrides:
    ios:
      home_indicator_safe_area: required
    macos:
      title_bar_alignment: trailing
  states: [initial, loading, data, error, empty]
  routes: [login, deal_list, settings]
```

## Success Criteria

- **SC-001**: The spec for 004-login-ui contains an explicit Skin Contract section (`example/specs/004-login-ui/spec.md`).
- **SC-002**: `zfa tdd plan 004-login-ui` produces 04-SKIN.md with platform rows, state-machine rows, and route rows.
- **SC-003**: The contract is JSON-parseable and schema-validated in a test (`test/plugins/tdd/commands/plan_skin_contract_1004_test.dart`).
- **SC-004**: The spec template documents the Skin Contract grammar (`.specify/templates/spec-template.md`).
