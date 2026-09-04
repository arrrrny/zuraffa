# Tasks: UI Coverage Ledger + XRay Gatekeeper (075)

**Feature**: specs/075-ui-coverage-ledger | **Issue**: arrrrny/zuraffa#963
**Input**: design documents from `specs/075-ui-coverage-ledger/`

## Phase 1: Setup

- [ ] T001 Scaffold `specs/075-ui-coverage-ledger/tdd/` (derived via `zfa tdd plan`)

## Phase 2: Behaviors (TDD — red first)

- [ ] T002 **[behavior U1]** Plan derives ledger rows from declared texts/routes/affordances with kinds — `services/ui_ledger_builder.dart` (new) + `plan_command.dart`
- [ ] T003 **[behavior U2]** A surface with no provers appears as NOT-DONE at plan time (never omitted)
- [ ] T004 **[behavior U3]** Provers are the behaviors whose scenario assertions name the surface (finder-taxonomy linkage)
- [ ] T005 **[behavior U4]** Non-declared quotations (absent:/example values) do not become rows
- [ ] T006 **[behavior U5]** State derives from CURRENT evidence: a prover green ⇒ DONE; planned-but-red ⇒ NOT-DONE — evidence read from registry/cycle log
- [ ] T007 **[behavior U6]** `zfa tdd coverage` emits the JSON verdict + summary line, exit 0 iff no gaps — `commands/coverage_command.dart` (new)
- [ ] T008 **[behavior U7]** Each gap names the surface + the behavior to write or the declaration to add
- [ ] T009 **[behavior U8]** A feature with zero declared surfaces exits 0 with an empty verdict
- [ ] T010 **[behavior U9]** Merge composition: the coverage gate runs as 074's `coverage` check; an incomplete ledger blocks the landing naming gaps
- [ ] T011 **[behavior U10]** XRay overlay paints by ledger state; unproven highlighted, proven clean — xray plugin wiring
- [ ] T012 **[behavior U11]** No ledger ⇒ overlay reports absence (never painted as proof)
- [ ] T013 **[behavior U12]** The deck lists ledger rows with states; state refreshes from the ledger artifact
- [ ] T014 **[behavior U13]** The xray mock scaffolder enumerates 072 dependency mocks + fixture scenarios as deck entries; a missing mock names `--> fix: zfa mock dependency <Name>`
- [ ] T015 **[behavior A1]** End-to-end login-shaped spec: ledger = 8 texts + 1 route + 3 affordances; gate exit-coded; seeded gap named; overlay highlights exactly the gap

## Phase 3: Wiring & polish (non-behavior)

- [ ] T016 Ledger artifact + verdict models; CLI flags/help; docs + openwiki touchpoints

## Phase 4: Verification

- [ ] T017 `dart analyze` clean; scoped suites green; spec-whole verify (audit) for the feature
