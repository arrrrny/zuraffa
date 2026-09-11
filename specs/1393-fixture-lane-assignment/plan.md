# Implementation Plan: 1393-fixture-lane-assignment

**Branch**: `feat/1393-fixture-lane-assignment-fix`
**Spec**: [spec.md](./spec.md)
**Issue**: arrrrny/zuraffa#1393 (EPIC #1012 exit criterion 4)
**Created**: 2026-09-11

## Technical Context

**Language/Version**: Dart 3.13.3 / Flutter 3.47.3 stable
**Fixture**: `example/specs/004-login-ui` (the flagship lane-split fixture;
separate Flutter package with its own pubspec)
**Primary artifacts touched**: the fixture spec markdown only — lane
assignments (`## Lanes`), FR traces rows (`traces:` grammar, issue #1313),
and the Skin Contract yaml (issue #1004 grammar)
**Testing**: structural pin suite (`test/plugins/tdd/commands/
bug_1393_fixture_lane_pin_test.dart`) + the real CLI cycle
(`zfa tdd plan` / `zfa tdd run 004-login-ui --project example`)
**Target runtime**: the two-cycle driver (spec 1008) inside the zuraffa repo

### CORE = engine-only contract

The engine lane (CORE) is pure Dart: the noFlutter guard refuses any
engine-destined behavior that references Flutter (plan_command
`_resolveLanes`), and a unit behavior whose contract trace resolves to a
**presentation** row routes to the view-generation surface — a layout-surface
row, not a callable — so its make stops vacuous-green (issues #1259/#1308).
A CORE unit behavior must therefore trace to a callable contract row whose
declared signature is engine-expressible: gen derives the subject shape and
the outcome assertion from the declared signature (issue #1259), and make
scaffolds the body for scalar declared returns (`bool|String|int|double|num`).

### FR traces rows

The `traces:` continuation line binds an FR to declared Layer Contracts rows
(`parseFrContractTraces`, spec 1313 grammar: indented `traces:` inside the FR
block). A method-qualified trace (`Row.method`) must name a signature the row
declares, else plan refuses with `danglingReference`.

### Skin Contract yaml syntax

`## Skin Contract` parses through the strict production parser
(`parseAdaptiveSkinContract`): every declared identifier must match
`^[a-z][a-z0-9_]*$`, unknown keys refuse. The malformed
`adaptive_slots: obile, ios, android, macos]` named in #1393 fails the name
pattern — the parser's own negative fixture. On master the declaration is
already valid (spec 1377 recorded the repair); this fix pins it.

## Rationale

The failure is spec drift, not engine drift: the shipped fixture predates the
lane grammar's CORE=engine-only contract. The minimal honest remediation is a
data fix in the fixture spec — (1) U1 → SKIN where view-presentation work
lives (the #1005 hand-written seam), (2) a new engine-side FR whose trace
binds to a declared scalar-return callable row (`LoginValidation.
isSubmittable(String email, String password) -> bool` — the credential
verdict gate, mirroring the pure-Dart login slice the repo-root fixture
declares), (3) commit the re-split evidence (`zfa tdd split --force`, the
sanctioned one-shot re-split verb, issue #1309), and (4) pin all of it
structurally so the vacuous-green stop and the zero-anchor unexpressible
stop can never regress silently.

No engine, plan, gen/make pipeline, or verify-gate code changes: the loop
already implements every mechanism correctly (the reproduction proved each
guard fires exactly as designed).

## Design

- **Lanes**: CORE `[A1, A2, U2]`, SKIN `[W1, U1, A3, A4, A5, A6, A7]`;
  adaptive_slots unchanged `[mobile, ios, android, macos]` (the #1004 drift
  cross-check between the Skin Contract slots and the SKIN lane slots stays
  satisfied).
- **FR-002** (new): the credential-verdict submit gate; traces
  `LoginValidation.isSubmittable`; the **Function** row declares
  `isSubmittable(String email, String password) -> bool` — typed scalar
  params (representative literals at the gen capture site — issue #1323) and
  a scalar return (the `isA<bool>()` outcome assertion — issue #1259).
- **Composition chain** (spec 052): U2 goes green in phase 1 (func scaffold);
  A1/A2 acceptance makes defer to phase 2 and compose against U2's green
  subject anchor (`CompositionTargets` green-evidence discovery), implemented
  by `zfa tdd compose` + build — unattended.
- **Evidence**: the regenerated lane plans, split receipt, traceability,
  artifacts registry, cycle log (red → green → refactor per behavior), and
  the green `04-engine-receipt.json` are committed, mirroring the spec 1377
  precedent for fixture evidence.

## Verification Rehearsal

- `zfa tdd plan 004-login-ui --project example` → routing provenance shows
  `U2 -> unit lane (func surface) [declared: contract row: LoginValidation]`
  and the split carries U1 in SKIN.
- `zfa tdd split 004-login-ui --force --project example` → the receipt
  carries the re-split classification (#1309 escape).
- `zfa tdd run 004-login-ui --project example` → engine receipt green
  (SC-002); the skin lane stops at the designed U1 hand-delta seam
  (issues #1259/#1308) — recorded, not a defect of this fix.
- Pin suite `dart test test/plugins/tdd/commands/
  bug_1393_fixture_lane_pin_test.dart` → 4/4 (SC-001).
