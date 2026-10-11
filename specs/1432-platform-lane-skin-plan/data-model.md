# Data Model: platform-typed acceptance scenarios are first-class SKIN lane rows

No persistent entities change. The feature is planner behavior over the
existing in-memory model; this document pins the model shapes the fix
touches.

## BehaviorKind (existing enum — the fix's axis)

`acceptance, unit, widget, theme, ffi, platform, contract`

- Source of truth for a row's kind: the routing decision (declared `Type`
  marker or contract-row trace, with the labeled legacy fallback).
- The lane plan renderers partition `LaneRow`s by kind into sections. The
  partition must be TOTAL over the kinds a lane can receive: a kind with no
  section is the #1432 defect class.

## LaneRow (existing — the rendered unit)

| Field | Type | Role in the fix |
| ---- | ---- | -------------- |
| id | String | the behavior id asserted present in the artifact (SC-002) |
| description | String | row text (unchanged for platform rows) |
| traces | String | criterion + resolved contract-row names (unchanged) |
| state | String | `PENDING` at plan time (unchanged) |
| kind | BehaviorKind | **the axis of the defect** — platform rows matched no section filter |
| lane | Lane | CORE/SKIN/BOTH — which plan file(s) the row must appear in |
| golden | bool | unchanged (widget-only gate) |

## Section homes after the fix

| Lane plan | Sections (kind → section) |
| -- | -- |
| `04-ENGINE.md` | acceptance+**platform** → Outer loop: acceptance; widget → Outer loop: widget; unit → Inner loop; ffi → Native loop |
| `04-SKIN.md` | acceptance+**platform** → Outer loop: acceptance; widget → Outer loop: widget; unit → Inner loop |
| `04-CONTRACT.md` | BOTH seam table (unchanged; #1419 owns contract rows) |

## Refusal guard (new, plan-time)

Input: every spec-derived behavior + its resolved lane.
Property: `kind ∈ homeKinds(destination plan)` for each destination the lane
renders; BOTH requires membership in both home sets.
Violation → refusal (exit 2, no artifacts) naming id, kind, criterion, and
the `--> fix:` remedy. Today's only reachable violation class: `theme`.
`contract` rows are excluded (open #1419).

## State invariants

- Route log ↔ artifact: every `route: <id> -> <lane>` line has a
  corresponding row with `<id>` in that lane's plan file (SC-002).
- Counts: the plan summary's per-lane behavior counts equal the number of
  data rows the artifact carries (SC-004) — by construction once the
  partition is total.
