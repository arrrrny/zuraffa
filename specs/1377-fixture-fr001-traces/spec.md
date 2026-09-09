**Template Version**: `zuraffa-1.0`

# Spec: 1377-fixture-fr001-traces

GitHub issue: arrrrny/zuraffa#1377 (verify-misfire / spec-drift, EPIC #1012
Phase A / exit criteria 3+4, #1000/#1008)

## Summary

The flagship fixture `example/specs/004-login-ui` could not go
engine-green: FR-001 carried no `traces:` line to a declared Layer
Contracts row, so its unit behavior U1 was fallback-routed and make
correctly refused the guard-only test vacuous-green (issues
#1259/#1308 — the guard worked as designed; the fixture predated the
#1186/#1313 grammar and was never migrated). The malformed
`adaptive_slots:` YAML lines named in the issue are already repaired on
master.

## Locked decisions

1. Data fix: FR-001 gains `traces: adaptive_layouts` — bound to the
   declared Layer Contracts row (the issue's suggested fix + applied
   workaround).
2. A structural pin (B1/B2) locks the migration: FR-001 carries
   `traces:` bound to a row that is declared — no dangling trace.
3. The regenerated plan evidence (declared routing for U1, refreshed
   lane plans + split receipt via the #1366 mechanism) is committed.
4. U1's vacuous-green make stop remains the DESIGNED hand-delta for a
   view-layout behavior (issues #1259/#1308): `adaptive_layouts` is a
   layout-surface row, not a callable function contract, so the engine
   test's guard is honest until the author implements the view. Not a
   defect; recorded.

## Functional requirements

- **FR-1**: FR-001 in the shipped fixture carries `traces:
  adaptive_layouts`.
- **FR-2**: the traced row is declared in the fixture's Layer Contracts
  section.
- **FR-3**: plan routes U1 as DECLARED (`contract row: adaptive_layouts`),
  not fallback.

## Acceptance scenarios

1. The pin reads the fixture spec → FR-001 block contains `traces:` (B1).
2. The traced row name appears in the Layer Contracts section (B2).
3. `zfa tdd plan 004-login-ui --project example` → the provenance names
   `route: U1 -> unit lane (view generation) [declared: contract row:
   adaptive_layouts]` (verified; committed evidence).

## Success criteria

- **SC-001**: The fixture's unit behavior routes DECLARED — the
  fallback/legacy-classifier path is gone for U1.
- **SC-002**: The shipped contract text is valid YAML (already repaired
  on master; the pin guards the traces migration).

## Assumptions

- U1's guard test remains the designed starting state for the view
  behavior; the author hand flow (#1258/#1259) is the sanctioned
  continuation.
