# tdd.verify — Bug #1589 blocked contracts dead-end the resume path + poison the phase-2 refactor pass

- **Verified**: 2026-09-13, this session, on
  `fix/1589-contract-blocked-dead-end-resume` (working tree, pre-push)
- **Toolchain**: Dart 3.13.3 (stable) on linux_x64
- **Scope**: `lib/src/plugins/tdd/commands/run_driver_core.dart`,
  `lib/src/plugins/tdd/commands/make_command.dart`,
  `lib/src/plugins/tdd/commands/verify_red_command.dart`,
  `lib/src/plugins/tdd/commands/refactor_command.dart`,
  `lib/src/plugins/tdd/services/step_runner.dart`,
  `lib/src/plugins/tdd/models/generation_plan.dart`, the new
  `lib/src/plugins/tdd/services/hand_surface.dart`, and the new suites
  `test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart` +
  `test/plugins/tdd/bug_1589_refactor_parked_seam_test.dart`.

## Verdict: PASS

## 1. Static analysis

```
dart analyze <7 changed lib files + 2 new test files>
→ No issues found!          (re-checked after dart format)

dart analyze            (whole repo)
→ 112 issues found      (all `info`)
→ errors/warnings: 0    (baseline: 0 — no new warnings)
```

The whole-repo count is identical to the pre-change baseline measured on
this branch's parent state (112 info lints, 0 errors, 0 warnings).

## 2. The bug suites (REAL runs in this session)

```
dart test test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart
→ 00:06 +8: All tests passed!

dart test --preset=all test/plugins/tdd/bug_1589_refactor_parked_seam_test.dart
→ 00:05 +6: All tests passed!
```

REQUIRED checks — the issue's success criteria are PROVED by real runs,
not inspection:

- **Blocked stop names the hand surface (criterion 1)**: the park note and
  the terminal `result=blocked` block print
  `hand surface: seam test/tdd/004-login-ui/contract_a1_test.dart — …
  (e.g. `zfa tdd wire contract:A1 --entity User`)`; verify-red's verdict
  carries the same line on stderr (asserted via the make/refactor
  neighbors and the shared `HandSurface` helper). Pre-fix: none of it.
- **make accepts the blocked verdict / says "implement seam first"
  (criterion 2)**: `zfa tdd make contract:A1` on a parked contract
  (receipt on disk, unchanged world) exits non-zero with
  `outcome=implement-seam-first`, prints "implement seam first" + the hand
  surface, and no longer prints the dead-end "has no certified-red
  evidence … Run verify-red first"; no green evidence is appended. The
  fail-open guards (world changed / receipt missing / non-contract
  target) keep the existing refusal — verified pre- AND post-fix.
- **Parked behaviors exempt from the phase-2 refactor gate (criterion
  3)**: a parked contract hands its seam to every refactor spawn
  (`--parked-seam test/tdd/004-login-ui/contract_a1_test.dart` in the
  spawned argv — this-run parking AND resume skip); the gate tolerates a
  preflight/re-proof red confined to that file (`outcome=clean` /
  `outcome=refactored`, exit 0), still refuses a NEW failure elsewhere,
  still refuses without the flag, and fails closed on an unparseable
  transcript.
- **Resume instructions followable as written (criterion 4)**: the stop
  names WHERE (the seam file) and HOW (`zfa tdd wire contract:A1 --entity
  User`) — asserted verbatim in the bug suites.
- **Hard constraints**: the #1007/#1544 pins pass untouched
  (`contract_kind_1007_test.dart` 18 tests, including
  `result=blocked blocked=1 stopped_at=contract:A1:verify-red` and the
  receipt/skip/fail-open resume semantics), and
  `contract_blocked_e2e_1007_test.dart` +
  `contract_satisfied_with_rejection_e2e_1541_test.dart` (real-runner
  e2e) pass 20/20.

## 3. Kernel/disk hygiene (verify protocol)

```
rm -rf .dart_tool/test/ && rm -f /tmp/dart_test.kernel.*   # before EVERY chunk below
dart analyze $(git diff --name-only HEAD~2 -- '*.dart' | tr '\n' ' ')
→ No issues found!
dart format <touched files> && git diff --stat   # formatting landed; suites re-run after
```

## 4. Changed-file counterpart suites (REAL runs)

`step_runner_test.dart` (+51), `make_command_*` (5 suites beyond
make_command_test), `verify_red_command_test.dart` / `verify_red_subdirectory_test.dart`,
`refactor_command_test.dart` (+22 incl. bug_922), the run-driver battery
(`run_command_test.dart` +79 across `two_cycle_run_commands_test.dart`,
`issue_1482_run_preflight_driver_test.dart`, `issue_1308_vacuous_guard_remedy_driver_test.dart`,
`issue_1323_hand_delta_driver_test.dart`;
`run_engine_command_test.dart`/`run_skin_command_test.dart`/`run_command_bug_1471_test.dart`
+43; `bug_1271`/`bug_1373`/`bug_1411` +28; `bug_1472` ×2 + `bug_1333` +
`bug_1540` +27; `bug_1542`/`bug_1520`/timeout-receipts +10).

## 5. Pre-existing failures (A/B-verified, NOT introduced here)

The spawn-heavy suites below fail IDENTICALLY on the pristine parent
commit (52ebc3cf, worktree A/B) and on this branch — environment-bound
pre-existing red, zero new failures from this fix:

- `make_command_test.dart`: `U-829g`, `U-829h`, `A11/U17`, `A15`
  (4/40; identical sorted failure sets base vs branch).
- `verify_red_command_test.dart`: `U23/A1` (1/24; fails on base too).
- `bug_922_refactor_preflight_baseline_test.dart`: the real-`dart test`
  end-to-end "a green behavior behind a baseline-red suite reaches done"
  (fails on base too; the #922 verdict logic itself is green on both).

## 6. Verdict summary

- New behavior: 14/14 bug-suite tests green (post RED — the same 10 tests
  failed pre-fix at exactly the reported symptoms).
- Unchanged behavior: every pinned neighbor suite green; the BLOCKED
  verdict, the contract lane, and the state machine are byte-identical.
- Static analysis: no new warnings; formatting clean.

## 7. Artifacts

- `.specify/bugs/1589-contract-blocked-dead-end-resume/` — assessment.md,
  issue.md, fix.md, test.md, red-evidence.md
- `tdd/test-list.md` (this bug's list, repo root), `tdd/verification.md`
  (this file)
- Branch `fix/1589-contract-blocked-dead-end-resume`, PR closing #1589
