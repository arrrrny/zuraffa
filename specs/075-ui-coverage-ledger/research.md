# Research: UI Coverage Ledger + XRay Gatekeeper (075)

## R1 — Ledger sources

- **Texts**: the quoted-literal contract parsed by 071/#981's
  `FinderTaxonomy` (presence literals) — the same literals widget tests
  assert. Scenario quotation alone is the declaration; examples/values
  marked `absent:` or non-surface quotes are excluded.
- **Routes**: the Presentation layer-contract row / declared route
  entries (071 ContractRowDecl kind `presentation`).
- **Affordances**: scenarios name interactive surfaces ("3 button
  affordances") — declared via scenario surface markers
  (`affordance: "Sign in"` in the scenario prose or the behavior's
  surface annotations). Only named affordances enter; nothing is
  inferred from widget trees.

**Decision**: derive rows at plan time into
`specs/<feature>/tdd/ui-ledger.md` (+ `.json` twin), each row:
surface, kind, provers (behavior ids that assert it — already computed
by the finder taxonomy's scenario-assertions header), state.

## R2 — State = evidence

A row's provers are green only when the cycle log/registry records
green for them (the make/loop writes green evidence; #981's kind gate
guarantees the green is verb-matched). **Decision**: state recomputes
at gate/overlay read time from the registry + cycle-log — stale DONE
cannot survive a re-check (edge case honored by construction).

## R3 — The gate command

`zfa tdd coverage <feature>` reads the ledger + evidence:

```text
coverage: feature=<f> surfaces=<n> proven=<n> unproven=<m> outcome=<complete|gaps>
```

JSON twin per row `{surface, kind, provenBy, state}`; exit 0 iff
`m == 0`. Failures list each unproven surface + `--> fix: write/land the
proving behavior (<ids>)` or `--> fix: declare the surface in the spec`.

## R4 — Merge composition (074)

The conformance verdict gains `coverage` as a fifth check calling the
same gate — one implementation, two consumers. On hosts without 074 the
command runs standalone in CI.

## R5 — XRay wiring

The xray plugin (`plugins/xray/`, `xray_command.dart`,
`xray_deck_command.dart`, `xray_mock_command.dart`) already parses
`@XRayMock` + scenario YAML and ships overlay/deck surfaces.
**Decisions**:
- `xray enable` gains a ledger source: the overlay paints by row state;
  absent ledger ⇒ "no ledger" state, never clean.
- `xray deck` lists ledger rows with states (single inventory — the
  ledger — behind both overlay and deck).
- `xray mock <Entity>` → generalized to dependency mocks: enumerates
  the 072 registry records (`dependency:<Name>`) + fixture scenarios as
  deck entries; missing mocks name the generation fix.

## R6 — Alternatives rejected

- **Scanning produced code for strings** (post-hoc surface discovery):
  rejected — discovers accidentals, rewards hardcoding; declarations
  are the contract.
- **A new overlay data format**: rejected — the ledger IS the format;
  the overlay reads it directly.
- **Gate inside make**: rejected — coverage is a landing/CI gate; make
  reports per-behavior outcomes already.
