# TDD test list — Bug #1589 blocked contracts dead-end the resume path + poison the phase-2 refactor pass

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1589-a1 | test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart | unit | the park note names the hand surface: seam path + `zfa tdd wire contract:A1 --entity User` | issue #1589 criterion 1, #1007 park arm | GREEN |
| U-1589-a2 | test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart | unit | the terminal `result=blocked` block names the hand surface per parked row; verdict/lane/state pins hold (`blocked=1 done=1`, `stopped_at=contract:A1:verify-red`) | issue #1589 criteria 1+4, #1007/#1544 pins | GREEN |
| U-1589-a3 | test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart | unit | a contract parked THIS run hands its seam to every refactor spawn (`--parked-seam`) | issue #1589 criterion 3, driver handoff | GREEN |
| U-1589-a4 | test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart | unit | a still-blocked SKIP on resume (persisted parking + receipt) hands the seam to the refactor spawn too | issue #1589 criterion 3, #1544 skip arm | GREEN |
| U-1589-a5 | test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart | unit | `make contract:A1` on a parked contract (receipt + unchanged world) refuses `implement-seam-first` naming the hand surface; the dead-end "has no certified-red evidence" remedy is gone; no green evidence written | issue #1589 criterion 2, #1007 contract lane | GREEN |
| U-1589-a6 | test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart | unit | a changed world (lib/ newer than the verdict) fails OPEN to the existing not-certified-red refusal | fail-open guard, #1544 watch set | GREEN |
| U-1589-a7 | test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart | unit | a missing receipt fails OPEN to the existing refusal | fail-open guard | GREEN |
| U-1589-a8 | test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart | unit | a NON-contract behavior without red evidence keeps the existing refusal (contract-lane scoping) | scoping guard | GREEN |
| U-1589-b1 | test/plugins/tdd/bug_1589_refactor_parked_seam_test.dart | unit | a preflight red whose ONLY failure lives in a handed parked seam is tolerated (`outcome=clean`, exit 0, no mutation) | issue #1589 criterion 3, #922 economics | GREEN |
| U-1589-b2 | test/plugins/tdd/bug_1589_refactor_parked_seam_test.dart | unit | WITHOUT the flag the same red still refuses — flag-less standalone refactor keeps the absolute-green contract (spec 048 FR-001) | contract-preservation guard | GREEN |
| U-1589-b3 | test/plugins/tdd/bug_1589_refactor_parked_seam_test.dart | unit | a NEW failure beyond the handed parked seam still refuses — the tolerance is surgical | safe-failure guard | GREEN |
| U-1589-b4 | test/plugins/tdd/bug_1589_refactor_parked_seam_test.dart | unit | a parked-seam failure BESIDE baseline-recorded failures is tolerated too — the #922 and #1589 economics compose | composition | GREEN |
| U-1589-b5 | test/plugins/tdd/bug_1589_refactor_parked_seam_test.dart | unit | a re-proof red confined to the handed parked seam is NOT a regression (`outcome=refactored`, exit 0) | re-proof tolerance | GREEN |
| U-1589-b6 | test/plugins/tdd/bug_1589_refactor_parked_seam_test.dart | unit | an UNPARSEABLE red is never parked-tolerated — fail closed (`outcome=not-green`) | U18 fail-closed guard | GREEN |

## Red evidence (pre-fix, this session)

Verbatim runs preserved in
`.specify/bugs/1589-contract-blocked-dead-end-resume/red-evidence.md`:

- Suite 1 (pre-fix): `+3 -5` — no hand surface in any blocked stop; the
  refactor spawn argv carries no `--parked-seam`; `make contract:A1`
  dead-ends with "has no certified-red evidence … Run `zfa tdd verify-red`
  first" (the loop the issue reports). The 3 fail-open/scoping guards were
  already green pre-fix (they pin behavior that must not change).
- Suite 2 (pre-fix): `+1 -5` — the `--parked-seam` flag does not parse
  (usage exception) and the gate refuses/regresses on the parked verdict's
  own failure; the flag-less absolute-green guard was already green.

## Suite placement note

The behaviors live beside their neighbors: the driver/make suite in
`test/plugins/tdd/commands/` (colocated with
`bug_1544_run_continue_after_blocked_test.dart` and
`contract_kind_1007_test.dart`, fast tier, fake-zfa scripted) and the
refactor-gate suite in `test/plugins/tdd/` (colocated with
`bug_922_refactor_preflight_baseline_test.dart`, `slow` tag per the
refactor-command convention, spy-scripted suite). Both run in the chunked
sweep; the slow file via `--preset=all`.
