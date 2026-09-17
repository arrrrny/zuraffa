# TDD test list — EPIC 1133 epic-closing lane (re-verify the four exit criteria on current master + green the U1 preflight blocker)

The full lane record (red/green evidence, commands, hashes) lives at
`.specify/specs/1133-tdd-loop-completeness/tdd/test-list.md`.

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| E-1133-1 | example/test/tdd/004-login-ui/a4_test.dart | widget | AC-4 asserts a REAL route outcome (`observer.pushedNames contains 'deal_list'`), re-proved by hermetic regeneration this session | exit criterion 1 | GREEN (re-proved) |
| E-1133-2 | example/test/tdd/004-login-ui/a5_test.dart | widget | the hides scenario carries `findsNothing` (`absence("t.auth.error")`), re-proved by hermetic regeneration | exit criterion 2 | GREEN (re-proved) |
| E-1133-3 | example/specs/004-login-ui/tdd/verification.md | audit | `zfa tdd verify --feature 004-login-ui` full real run: all 5 behavior kinds traced (presence=2 absence=1 route-outcome=2 enabled-state=1 sequence=1) | exit criterion 3 | RAN (fail_survived gate, 58/9/0, score 0.8657) |
| E-1133-4 | example/test/tdd/004-login-ui/a3_test.dart (+a7 de pumps) | widget | LocaleTests resolve slang keys; German expansion pump passes at 318–364% anchor length | exit criterion 4 | GREEN (re-proved) |
| U-1133-5 | example/test/tdd/004-login-ui/u1_test.dart | unit | U1 green (the Skin Contract's declared adaptive_slots) — unblocks the registry's 10-behavior preflight left red by the #1393 re-split | epic unblock | RED → GREEN (this session) |

## Red evidence (pre-fix, this session)

`zfa tdd verify --feature 004-login-ui` on pristine master →
`gate: preflight_red`, mutation_was_run=false; per-behavior preflight
failed at `u1_test.dart`:
`Actual: UnimplementedError: subject_u1 not implemented`.

## Green evidence (this session)

`flutter test test/tdd/004-login-ui/u1_test.dart` → `+1: All tests
passed!`; full 10-file scope → `+12: All tests passed!`; the verify audit
then ran to completion (58 killed / 9 survived / 0 timed out, restoration
verified over all 10 subjects).
