# Implementation Plan: Login UI — `004-login-ui`

**Branch**: `verify/epic5-simulation-replay-proof`
**Spec**: `specs/004-login-ui/spec.md`
**Created**: 2026-09-09

## Technical Context

**Language/Version**: Dart 3.13.3 (pure Dart; no Flutter import in this slice)
**Primary dependency**: zuraffa 6.2.2 (the package under verification)
**Storage**: N/A — no persistence in this feature slice
**Testing**: `dart test` (fast tier), subjects under `test/tdd/004-login-ui/`
**Target runtime**: CLI-driven TDD loop (`zfa tdd *`) inside the zuraffa repo itself

## Rationale

EPIC 5 (#1136) exit criterion 2 requires `zfa spec fuzz 004-login-ui` to run and
report survived mutants. The verify run (misfire #1357) proved the fuzz arena
engine works (see `test/plugins/tdd/spec_fuzz_demo_test.dart`, integration tier)
but refused every real feature: `004-login-ui` did not exist and no committed
feature carried registered behavior artifacts. This plan closes that gap by
scaffolding `004-login-ui` as a minimal, honestly-specified login-form slice
whose behaviors are pure-Dart testable (credential verdict, submit gating,
auth-attempt mapping) so the engine lane can go green without build_runner or a
Flutter SDK.

The spec deliberately mirrors the zuraffa-1.0 template grammar that
`SpecParser` consumes: numbered Given/When/Then acceptance scenarios with
`**Type**` markers, FR bullets, Key Entities table, and an External Dependencies
& Contracts row (`AuthGateway`) so downstream `zfa simulate init` composition
(VISION §9) can treat the row as a touchpoint.

## Design

- `LoginCredentials` and `LoginResult` are immutable value types (Zorphy-style
  plain classes; no codegen to keep the loop light).
- `validateLogin(credentials) -> LoginVerdict` — pure function; the P1 story's
  subject. Verdict carries `ok` plus an ordered reason list (email reasons
  precede password reasons; empty input names the email field first).
- `submitLogin(credentials, AuthGateway) -> LoginResult` — pure-ish mapper over
  the declared `AuthGateway.signIn` contract; success carries the user email,
  failure carries a non-empty reason, never both non-null.
- Subjects live in `lib/src/login/` (feature-owned, registry-tracked).

## Technical Context notes

No deviations from the constitution: the slice is pure Dart (Constitution VII),
subjects are framework-certifiable, and every generated pair is registered in
`specs/004-login-ui/tdd/artifacts.json` so the spec-mutation arena can derive
its scope (the exact mechanism misfire #1357 found missing).

## Verification Rehearsal

- `zfa tdd plan 004-login-ui` → `specs/004-login-ui/tdd/test-list.md`
- `zfa tdd gen --feature 004-login-ui --all` → failing pairs + registry rows
- `zfa tdd verify-red --feature 004-login-ui` → red evidence
- implement subjects → `dart test test/tdd/004-login-ui/` → green
- `zfa tdd run 004-login-ui` → engine receipt + unified journal entry
- `zfa spec fuzz 004-login-ui --budget 5` → killed/survived verdict (EPIC exit
  criterion 2)
