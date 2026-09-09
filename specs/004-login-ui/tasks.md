# Tasks: Login UI — `004-login-ui`

**Input**: Design documents from `/specs/004-login-ui/`
**Prerequisites**: plan.md ✓, spec.md ✓

## Format

- `[P]` = can run in parallel with other `[P]` tasks in the same phase
- Every behavior task is gated by a failing test (TDD — see tdd/test-list.md)

## Phase 1 — Setup

- [ ] T001 Scaffold feature directory `specs/004-login-ui/` with spec.md and plan.md (this cycle)
- [ ] T002 Run `zfa tdd plan 004-login-ui` to derive `tdd/test-list.md` from spec.md acceptance scenarios

## Phase 2 — TDD red (behaviors first)

- [ ] T003 `zfa tdd gen --feature 004-login-ui --all` — failing test + compiling stub per behavior, registered in `tdd/artifacts.json`
- [ ] T004 `zfa tdd verify-red --feature 004-login-ui` — capture red evidence that every registered test fails against its stub

## Phase 3 — TDD green (make)

- [ ] T005 Implement `lib/src/login/login_credentials.dart` + `login_result.dart` value types
- [ ] T006 Implement `lib/src/login/validate_login.dart` so AC-1..AC-4 tests pass (email shape per FR-001, password policy per FR-002, ordered reasons, deterministic per FR-006)
- [ ] T007 Implement `lib/src/login/submit_login.dart` so AC-5..AC-6 tests pass (success maps email/error null; failure maps reason/email null — FR-004/FR-005)
- [ ] T008 Run `dart test test/tdd/004-login-ui/` — all registered behaviors green

## Phase 4 — Proof

- [ ] T009 `zfa tdd run 004-login-ui` — engine receipt + unified journal entry (SC-001)
- [ ] T010 `zfa spec fuzz 004-login-ui --budget 5` — mutation round; record killed/survived in `tdd/spec-fuzz.md` (SC-002, EPIC #1136 exit criterion 2)

## Phase 5 — Polish

- [ ] T011 `dart format lib/src/login test/tdd/004-login-ui` — zero formatting drift
- [ ] T012 `zfa proof check` — receipt chain readable end-to-end (EPIC #1136 exit criterion 3 evidence)

## Dependencies

T002 → T003 → T004 → (T005..T007) → T008 → T009 → T010 → T011 → T012.
Value types (T005) block the subject implementations (T006, T007).
