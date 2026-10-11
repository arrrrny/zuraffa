# Bug Fix: 1625 — blocked-contract stop names the subject seam + entity-gated wire hint

- **Slug**: 1625-blocked-contract-hand-surface
- **Date**: 2026-09-15
- **Issue**: https://github.com/arrrrny/zuraffa/issues/1625
- **Branch**: `fix/1625-blocked-contract-hand-surface`
- **Mode**: TDD (red → green → verify), fast tier

## Root cause (verified in code)

`lib/src/plugins/tdd/services/hand_surface.dart`:

1. `seamPathFor` built candidates ONLY under `test/tdd/…` (the #827 namespaced
   layout + the legacy flat fallback) and returned the first that existed. The
   subject — `lib/tdd/<feature>/<id>_subject.dart`, the throwing stub the
   contract test imports (the convention `vacuous_guard.dart` already
   canonicalizes) — was never a candidate, so every blocked stop named the
   generated, registry-owned TEST file as the place to implement in.
2. `hintLine` → `wireCommandFor` synthesized `zfa tdd wire <id> --entity <E>`
   from the dotted contract trace without ever checking that the entity
   exists, while `zfa tdd wire` itself (wire_command.dart, via
   `locateEntityFile`) refuses exactly that command when no
   `lib/src/domain/entities/<snake>/<snake>.dart` is on disk — the hint
   handed the operator a guaranteed second dead end.
3. The verify-red blocked arm and the make implement-seam-first arm sourced
   the printed seam from `record.testPath` / `testPath` (the generated test),
   amplifying problem 1 at the two other blocked stops.

## Remediation (hand-surface detection + hint logic ONLY)

- `hand_surface.dart` — `seamPathFor`: the subject seam
  (`lib/tdd/<feature>/<snakeId>_subject.dart`) is now the FIRST candidate,
  existence-first; the two test candidates follow; the canonical display
  fallback (nothing on disk) is now the subject path — the file the operator
  creates and implements in. The class doc now says so.
- `hand_surface.dart` — new `entityExists(projectRoot:, entityName:)`: a sync
  mirror of `locateEntityFile`'s resolution (canonical path first, recursive
  scan fallback; probe errors read as absent so the always-valid
  hand-implement guidance wins in a broken tree). Reuses `toSnakeCase` from
  `entity_lookup.dart` — the exact conversion wire uses.
- `hand_surface.dart` — `hintLine`: `projectRoot` is now REQUIRED. With a
  dotted trace and the entity on disk, the with-entity wire example prints
  unchanged. With the entity missing, the hint prints the hand-implement
  instruction — `implement the declared contract <c> there by hand (no
  generated entity "<E>" exists; the wire step needs
  `zfa entity create -n <E>` first)` — never a command that would fail.
  Undotted traces keep the bare wire example (#1589's degradation).
- `verify_red_command.dart` + `make_command.dart` — the blocked arms now
  resolve the printed seam through `HandSurface.seamPathFor` (subject-first)
  and pass `projectRoot` to `hintLine`, so all three blocked stops name the
  same hand surface. The #1007 verdict/receipt/state machine, the #1544 park
  semantics and the wire mechanics are untouched.

## Deliberately NOT touched

- The `--parked-seam` refactor-gate handoff
  (`run_driver_core._existingGeneratedTestPath` → `_addParkedSeam`): it is
  the attested FAILING TEST the gate tolerates failures inside — a gate
  anchor, not a hand surface. Stays test-anchored and existence-gated.
- `wire_command.dart`: no changes whatsoever.

## TDD cycle evidence

- RED: `test/plugins/tdd/commands/bug_1625_blocked_hand_surface_subject_test.dart`
  — 11 tests, 7 failing for the right reasons (subject never preferred; wire
  hint unconditional; all three blocked stops naming the test file — the run
  transcript inside the failure output literally reproduces the issue's
  repro block), 4 passing (the pre-existing-behavior guards).
- GREEN: the fix above → 11/11 pass, and the #1589 regression suite passes
  (fixtures now seed the `User` entity so its with-entity pins exercise the
  entity-present shape under the new contract).
- Full cycle + evidence: see `tdd/verification.md` and `tdd/test-list.md`.

## Acceptance criteria mapping

1. Blocked-contract stop names the subject seam, not the test file — B1, B3,
   B7, B10, B11 (all three stops: run park note, terminal block, make; plus
   the verify-red arm resolved through the same `seamPathFor`).
2. `wire` command hint printed only when an entity of that name exists —
   B4, B5, B9.
3. When no entity exists, the refusal includes the hand-implement path —
   B5, B8, B11 (the named seam IS `lib/tdd/<feature>/<id>_subject.dart`, and
   the hint says "implement … by hand").
4. A fresh calculator spec's first blocked behavior points to the subject
   file — B7 (the fresh-run shape: generated test + subject on disk, no
   entity).
