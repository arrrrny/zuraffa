# Spec 0966: typed ledger rows — absence + state + sequence + navigation (ZIKZAK-REBUILD, extends #963)

**Issue**: arrrrny/zuraffa#966 · **Blocks/extends**: #963 (075-ui-coverage-ledger) · **References**: #959 (honest red), #964 (finder-kind taxonomy)

## Summary

The coverage ledger as specified in #963 traces **presence only**: every static text, route, and affordance mapped to a green behavior. Presence-only ledgers are gameable — demonstrated on the current 004-login-ui corpus — and blind to the two things that make UI wrong in practice: things that render when they shouldn't, and sequences.

## Problem: the gaming demonstration

A single `Column` rendering all 9 declared literals at once — error banner permanently visible, buttons always enabled, navigating nowhere — passes every A1–A4 presence assertion and posts a traceability matrix of **9/9 automated, 0 open gaps**. The ledger says 100% traced; the app is wrong in three different ways:

1. **No absence assertions** — nothing pins "error banner hidden until a failure occurs".
2. **No interaction sequences** — the `When` clause of every Given/When/Then is discarded; tap → loading → resolve is invisible.
3. **No state attributes** — "buttons disabled while in flight" (FR-005) cannot be expressed as a presence row.

## Proposal: typed ledger rows

Each ledger row carries a **kind**, and the #963 gate treats untraced kinds as gaps:

| kind       | traces                 | example                            |
| ---------- | ---------------------- | ---------------------------------- |
| presence   | rendered text/widget   | "Sign In" visible                  |
| absence    | not rendered in state S | error banner hidden initially     |
| navigation | route outcome          | sign-in → `deal_list`             |
| state      | widget attributes       | buttons disabled in flight        |
| sequence   | interaction chains      | tap → loading → resolve → navigate |

- The XRay overlay (#963) renders **kind coverage**, not just surface coverage — a page with presence-only rows shows as partially traced.
- Composes with the finder-kind taxonomy (#964): kinds are assigned at plan time from scenario verbs, not inferred post hoc.
- **Goldens**: keep out of the merge gate (flaky economics on slow CI), but allow advisory golden rows with per-platform tolerance. Deliberate decision, recorded.

## User stories

### Story 1: the gaming view must fail the gate

1. **Given** a login-shaped feature whose plan declares the 9 production literals plus absence and sequence scenarios ("error banner hidden until a failure occurs", "tap → loading → resolve → navigate"), **When** a ledger is derived where only the 9 presence rows are proven green (the all-9-literals-`Column` view), **Then** the coverage gate fails and names the untraced kinds — absence and sequence — as gaps.
2. **Given** the same feature with an honest ledger where an absence row is traced by a green behavior asserting the error banner hidden in the initial state, **When** the gate runs, **Then** the absence row reads DONE and the absence kind is no longer a gap.
3. **Given** a sequence row declared for the chain tap → loading → resolve → navigate, **When** a green behavior traces the chain end-to-end, **Then** the sequence row reads DONE with the chain named.
4. **Given** a state row declared for "buttons disabled while in flight" (an FR-005-class behavior), **When** a green behavior asserts the disabled attribute in the in-flight state, **Then** the state row reads DONE — FR-005-class behaviors are expressible and traced end-to-end in 004-login-ui.

### Story 2: kinds are assigned at plan time from scenario verbs

1. **Given** a scenario description carrying an absence verb ("hidden", "not shown", "does not render"), **When** the plan derives its ledger row, **Then** the row's kind is absence — never flattened to presence.
2. **Given** a scenario carrying a navigation verb ("navigates to", "routes to"), **When** the plan derives its ledger row, **Then** the row's kind is navigation.
3. **Given** a scenario carrying an attribute verb ("disabled", "enabled") without an interaction chain, **When** the plan derives its ledger row, **Then** the row's kind is state.
4. **Given** a scenario describing an interaction chain (tap → loading → resolve), **When** the plan derives its ledger row, **Then** the row's kind is sequence with the chain steps recorded.

### Story 3: the overlay renders kind coverage

1. **Given** a screen whose ledger holds presence rows only, **When** the XRay overlay renders the screen, **Then** it distinguishes kind coverage per screen — presence complete, absence/sequence untraced — and the screen shows as partially traced.
2. **Given** the deck, **When** it lists a screen's kind coverage, **Then** every declared kind appears with its traced/total counts and untraced kinds are named.

### Story 4: goldens stay advisory

1. **Given** a golden row (visual-snapshot surface) declared with per-platform tolerance, **When** the gate evaluates the ledger, **Then** the golden row is advisory — it never blocks the merge gate regardless of state, and the verdict records it as advisory (deliberate decision, recorded).

## Requirements

- **FR-001**: Each ledger row MUST carry a kind — `presence`, `absence`, `navigation`, `state`, or `sequence` — and the coverage gate MUST treat a declared kind with no traced row as a gap (untraced kinds are gaps), naming the kind.
- **FR-002**: An absence row MUST express "not rendered in state S" and MUST be traced (DONE) exactly when a green behavior asserts the surface hidden in that state (the error banner hidden initially is traced; a permanently rendered banner cannot satisfy it).
- **FR-003**: A sequence row MUST record the interaction chain steps (e.g. tap → loading → resolve → navigate) and MUST be traced (DONE) exactly when a green behavior traces the chain end-to-end.
- **FR-004**: A state row MUST record the asserted widget attribute (e.g. buttons disabled while in flight — FR-005-class) and MUST be traceable end-to-end in the 004-login-ui corpus.
- **FR-005**: Ledger row kinds MUST be assigned at plan time from scenario verbs (composing with the finder-kind taxonomy #964): absence verbs yield absence rows, navigation verbs yield navigation rows, attribute verbs yield state rows, interaction chains yield sequence rows, and default render verbs yield presence rows — never inferred post hoc and never flattened to presence.
- **FR-006**: The XRay overlay MUST render kind coverage per screen — every declared kind with its traced/total counts — so a screen with presence-only rows shows as partially traced; untraced kinds are highlighted, never painted as proof.
- **FR-007**: Golden rows MUST be advisory with per-platform tolerance: they are excluded from the merge-gate verdict (recorded decision — flaky economics on slow CI) and reported separately as advisory in the verdict and the deck.
