# Bug Verification: contract BLOCKED dead-ends the resume path + poisons the phase-2 refactor pass

- **Slug**: 1589-contract-blocked-dead-end-resume
- **Tested**: 2026-09-13
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: `tdd/verification.md` (repo root) — fresh from this session's real runs

## Summary

The bug no longer reproduces. The blocked stop (park arm, terminal
`result=blocked` block, verify-red verdict) names the hand surface — the
seam file path and `zfa tdd wire contract:<n>`. The documented resume path
`zfa tdd make contract:A1` now says plainly "implement seam first" with the
exact recovery instead of demanding certified red that verify-red can never
produce. A parked contract's failing seam test no longer poisons the
phase-2 refactor pass: the gate tolerates it (preflight AND re-proof) for
every spawn the driving run attests, while any NEW failure outside the
handed seams still refuses. The new suites failed on the pre-fix code at
exactly the reported symptoms (10 RED) and pass on this branch (14/14),
with the unchanged-behavior guards passing pre-fix by design.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| RED — driver/make suite (pre-fix) | `dart test test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart` | fail (expected) — `+3 -5` | no hand surface anywhere; `make` dead-ends with `not-certified-red` "run verify-red first" |
| RED — refactor gate suite (pre-fix) | `dart test --preset=all test/plugins/tdd/bug_1589_refactor_parked_seam_test.dart` | fail (expected) — `+1 -5` | `--parked-seam` unknown; gate refuses/regresses on the parked verdict's own failure |
| GREEN — driver/make suite | same file, post-fix | pass — `+8` | park + terminal hand-surface lines; refactor argv carries `--parked-seam` (this-run parking AND resume skip); make says `implement seam first`; 3 fail-open guards hold |
| GREEN — refactor gate suite | same file, post-fix | pass — `+6` | parked-only preflight tolerated (clean/exit 0); flag-less still absolute-green; NEW failure still refuses; composes with the #922 baseline; re-proof parked red is NOT a regression; unparseable fails closed |
| Verdict/lane/state-machine pins | `dart test … contract_kind_1007_test.dart bug_1544_run_continue_after_blocked_test.dart` | pass — 18/18 | `result=blocked blocked=1 stopped_at=contract:A1:verify-red`, receipt semantics, unchanged-skip, fail-open re-drive — all byte-identical |
| dart analyze (touched files) | `dart analyze <7 lib files + 2 test files>` | 0 issues | post-format |
| dart analyze (whole repo) | `dart analyze` | 112 info / 0 errors / 0 warnings | identical to the pre-change baseline (no new warnings) |
| dart format | `dart format <touched files>` | clean | re-ran suites after format |
| Regression — run driver neighbors | `dart test … step_runner_test.dart run_command_test.dart two_cycle_run_commands_test.dart issue_1482_run_preflight_driver_test.dart issue_1308_vacuous_guard_remedy_driver_test.dart issue_1323_hand_delta_driver_test.dart run_engine_command_test.dart run_skin_command_test.dart run_command_bug_1471_test.dart bug_1271_widget_lane_engine_deferral_test.dart bug_1373_scaffolded_hand_off_driver_test.dart bug_1411_born_green_hand_transition_test.dart` | pass — 122 + 28 | fast + slow tiers |
| Regression — make/verify neighbors | `dart test … verify_red_command_test.dart verify_red_subdirectory_test.dart make_command_widget_939_test.dart make_command_widget_950_test.dart make_build_step_classifier_test.dart make_command_1036_test.dart make_command_1565_test.dart make_command_declared_071_test.dart make_command_strict_071_test.dart bug_1372_certified_red_scan_test.dart` | pass, except 4 `make_command_test.dart` + 1 `verify_red_command_test.dart` failures | **pre-existing**: A/B-verified on the pristine parent commit (52ebc3cf) — identical failure sets (`U-829g`, `U-829h`, `A11/U17`, `A15`; verify-red `U23/A1`) |
| Regression — refactor neighbors | `dart test --preset=all … refactor_command_test.dart bug_922_refactor_preflight_baseline_test.dart bug_1472_refactor_gate_acceptance_test.dart bug_1472_refactor_gate_errors_only_test.dart bug_1333_refactor_reproof_retry_test.dart bug_1540_refactor_tracked_restore_test.dart bug_1542_born_green_contract_refactor_test.dart bug_1520_refactor_scratch_tmpdir_test.dart commands/run_driver_timeout_receipt_test.dart bug_1520_run_scratch_tmpdir_test.dart` | pass, except 1 `bug_922` end-to-end runner-error | **pre-existing**: A/B-verified on the pristine parent — same failure; the #922 verdict logic itself is green (22/23 file-local tests) |
| Contract-lane e2e (real runner) | `dart test --preset=all … contract_blocked_e2e_1007_test.dart contract_satisfied_with_rejection_e2e_1541_test.dart` | pass — 20/20 | the REAL-runner blocked/unblock paths keep their contracts |

## Interpretation

All four success criteria are met and pinned by real runs: (1) the blocked
stop names the hand surface; (2) `make` accepts the blocked verdict as a
precondition state and says plainly "implement seam first" (or fails open
to the honest refusal when the world changed); (3) a known parked behavior
does not fail the phase-2 refactor gate; (4) the resume instructions are
followable as written. The hard constraints hold: the BLOCKED verdict, the
contract lane and the state machine are untouched, and `dart analyze`
introduces no new warnings.
