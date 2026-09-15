# Bug Test Report: 1625 — verification audit

- **Slug**: 1625-blocked-contract-hand-surface
- **Date**: 2026-09-15
- **Issue**: https://github.com/arrrrny/zuraffa/issues/1625
- **Verdict**: **PASS** — the fix is verified against a real test run; all
  four acceptance criteria PROVED.

## 1. What was validated

- The fix commit on `fix/1625-blocked-contract-hand-surface` (see `fix.md`)
  against the acceptance criteria from the issue, through the new TDD suite
  `test/plugins/tdd/commands/bug_1625_blocked_hand_surface_subject_test.dart`
  (11 tests) plus the regression suites that guard the untouched contracts
  (#1589 hand surface, #1007 block gate/receipts, #1544 park semantics, wire
  mechanics).
- `tdd/test-list.md` (11 behaviors B1–B11) and `tdd/verification.md`
  (full evidence) accompany this report under `tdd/`.

## 2. Verification results (real run, this session)

- `dart test` targeted set (bug_1625 + bug_1589 + verify_red_command_test +
  verify_red_subdirectory_test + contract_blocked_e2e_1007 +
  bug_1544_run_continue_after_blocked + wire_command_test +
  contract_kind_1007 + contract_satisfied_with_rejection_e2e_1541):
  **58 passed / 0 failed**.
- `dart analyze` on the six touched files: **No issues found!**
- `dart format .` applied to touched files; committed tree is the formatted
  form.
- RED evidence preserved at commit `ed160e8` (4 pass / 7 fail with the
  failure output reproducing the issue's repro block).

## 3. Acceptance criteria

| # | Criterion | Verdict |
|---|-----------|---------|
| 1 | Blocked-contract stop names the subject seam, not the test file | PROVED (B1, B3, B7, B10, B11) |
| 2 | `wire` command hint printed only when an entity of that name exists | PROVED (B4, B5, B9) |
| 3 | No-entity refusal includes the hand-implement path (`lib/tdd/<feature>/<id>_subject.dart`) | PROVED (B5, B8, B11) |
| 4 | Fresh calculator spec's first blocked behavior points at the subject file | PROVED (B7) |

## 4. Pre-existing failures (flagged, unrelated)

Reproduced on clean `master` with the fix stashed, therefore NOT attributable
to this PR:

- `bug_1388_gen_traces_fingerprint_test.dart` — `PathNotFoundException` on a
  `/tmp` fixture path (fails in isolation on master).
- `make_command_test.dart` — 10 build-guard failures (identical count on
  master).
- Four suites flaked only under `--concurrency=4` directory-wide load;
  all pass in isolation on this branch.

## 5. Scope audit

- Diff touches exactly: `hand_surface.dart` (detection + hint), the three
  blocked-stop call sites (`run_driver_core.dart` ×2 messaging sites,
  `verify_red_command.dart`, `make_command.dart`), the new #1625 suite, and
  entity-seeding in the #1589 fixtures (required by the new entity-gated
  hint contract so the #1589 pins keep their meaning).
- The #1007 block gate, #1544 park semantics, `--parked-seam` gate handoff
  and `wire_command.dart` mechanics are untouched — pinned by the passing
  regression suites listed above.
