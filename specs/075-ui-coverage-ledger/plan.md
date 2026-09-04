# Implementation Plan: UI Coverage Ledger + XRay Gatekeeper (075)

**Branch**: `075-ui-coverage-ledger` | **Date**: 2026-09-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/075-ui-coverage-ledger/spec.md` (issue #963)

## Summary

Make "everything is traced" a checkable claim: the plan produces a per-feature **UI surface ledger** (texts from the quoted-literal contract, routes from the Presentation contract row, affordances named in scenarios — each with kind, provers, and evidence-derived state), a **`zfa tdd coverage`** gate emits an exit-coded JSON verdict (done only when every row is proven green) and composes as a merge gate with 074's conformance verdict, and the XRay plugin becomes the ledger's human face — the overlay paints surfaces by ledger state and the control deck drives the 072 dependency-mock rail's scenarios out of the box.

## Technical Context

**Language/Version**: Dart 3.13 (repo pins `sdk: ^3.11.0`)
**Primary Dependencies**: tdd plugin (plan/test-list/coverage sources), xray plugin (`lib/src/plugins/xray/`, `xray_command.dart`, `xray_mock_command.dart`, `xray_deck_command.dart`), 072 dependency-mock artifacts, 074 conformance verdict
**Storage**: ledger as a plan artifact (`specs/<feature>/tdd/ui-ledger.md` + JSON twin), verdict on stdout
**Testing**: `dart test` fast tier
**Target Platform**: CLI (+ in-app overlay library emitted into target apps)
**Performance Goals**: ledger derivation is a pure pass over existing artifacts; gate is O(rows)
**Constraints**: pure-Dart generator; overlay targets Flutter apps via generated code, never imported into the generator
**Scale/Scope**: one new artifact + one new command + wiring over existing xray/merge seams

## Constitution Check

- Test-first: behaviors land via `specs/075-ui-coverage-ledger/tdd/` red-first. ✅
- Errors-are-an-API: gaps name the surface + the behavior to write (`--> fix:`). ✅
- Green is the only proof: state derives from live cycle evidence, never plan intent. ✅
- Absence is not proof: no ledger ⇒ overlay/gate report absence, never pass. ✅

## Key Design Decisions

1. **Ledger sources are declarations, not quizzes.** Texts: the quoted-literal contract already parsed by the finder-kind taxonomy (071/#981). Routes: the Presentation contract row. Affordances: scenario-declared affordance markers. A surface nobody declares is not guessed (dynamic composition out of scope per spec).
2. **State is evidence-derived.** Ledger rows reference behaviors by id; state recomputes from the cycle log/registry at read time (plan intent is never "DONE").
3. **One gate, two consumers.** `zfa tdd coverage` emits the JSON verdict; merge composes it into the 074 conformance verdict as a fifth check (on hosts without 074 it runs standalone — CI-able).
4. **XRay reads the ledger, not a copy.** The overlay's paint state and the deck's row list derive from the ledger artifact; an absent ledger reports absence (never paints proof).
5. **Deck entries from the 072 rail.** The `xray mock` scaffolder enumerates dependency-mock artifacts and their fixture scenarios; a missing mock names `zfa mock dependency <Name>`.

## Project Structure

```text
specs/075-ui-coverage-ledger/
├── plan.md  research.md  data-model.md  quickstart.md
├── contracts/
│   └── coverage-gate.md        # ledger artifact + verdict + xray binding contracts
└── tdd/

lib/src/plugins/tdd/services/ui_ledger_builder.dart     # NEW: derive ledger rows
lib/src/plugins/tdd/commands/coverage_command.dart      # NEW: zfa tdd coverage
lib/src/plugins/tdd/commands/plan_command.dart          # emit ledger artifact
lib/src/plugins/slice/merger/… (074 composition point)  # fifth check
lib/src/plugins/xray/…                                   # ledger-driven overlay/deck wiring
test/plugins/tdd/075_*_test.dart                          # behaviors
```
