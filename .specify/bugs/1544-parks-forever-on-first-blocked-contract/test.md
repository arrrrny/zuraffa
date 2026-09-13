# Bug Verification: `tdd run` parks forever on the first BLOCKED contract

- **Slug**: 1544-parks-forever-on-first-blocked-contract
- **Tested**: 2026-09-13
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: `tdd/verification.md` (repo root) — fresh from this session's real runs

## Summary

The bug no longer reproduces. A blocked contract no longer terminates the
pass: the behavior parks at BLOCKED, the remaining behaviors drive to their
own verdicts in the SAME run, and the run stops at the end with
`result=blocked blocked=N`. A resume against an unchanged world skips the
still-blocked behavior with receipt (`skipped: still blocked since <ts>`)
and still drives everything else; any change signal (seam file, contract
row, implementation) — or a missing receipt — fails open and re-drives the
behavior honestly. The new bug suite failed on the pre-fix code at exactly
the reported symptoms (A2 unreachable; resume re-attempting A1) and passes
on this branch.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| RED — park/continue | `dart test test/plugins/tdd/commands/bug_1544_run_continue_after_blocked_test.dart` (pre-fix) | fail (expected) | A2/A3 never driven — the run terminated at `contract:A1 verify-red -> blocked` |
| RED — resume skip | same suite (pre-fix) | fail (expected) | resume re-spawned `verify-red contract:A1` — no skip receipt |
| GREEN — bug suite | same suite (post-fix) | pass | 6/6: park+continue, resume skip, seam-changed re-drive, impl-changed re-drive, missing-receipt fail-open, non-blocked resume guard |
| Regression — run driver neighbors | `dart test test/plugins/tdd/commands/contract_kind_1007_test.dart run_engine_command_test.dart run_skin_command_test.dart run_command_bug_1471_test.dart bug_1271_widget_lane_engine_deferral_test.dart bug_1373_scaffolded_hand_off_driver_test.dart bug_1411_born_green_hand_transition_test.dart` | pass | 51/51 — includes the #1007 single-row stop pin (`result=blocked`, `stopped_at=contract:A1:verify-red`, exactly `[gen, verify-red]`) |
| Regression — tdd commands | `dart test test/plugins/tdd/commands` | pass | 539/539 |
| Regression — tdd services | `dart test test/plugins/tdd/services` | pass | 935/935 |
| Regression — tdd top level | `dart test test/plugins/tdd/*.dart` (two halves) + the disk-failed set re-run | pass | 186 + 333 + 49, zero failures |
| Static analysis | `dart analyze` (whole repo) | pass | 112 `info` lints — identical to the pre-change baseline; **0 errors / 0 warnings**; changed files: `No issues found!` |
| Format | `dart format --output=none --set-exit-if-changed <changed files>` | pass | 0 changed |

## Evidence excerpts (real runs, this session)

Post-fix park + continue (new suite, test 1):

```
[run] contract:A1 verify-red -> blocked
   the declared contract User.validateEmail is not satisfied — the cycle is BLOCKED and cannot proceed to GREEN (issue #1007)
   parked — the run continues with the remaining behaviors (issue #1544)
[run] contract:A2 gen -> ok
...
run: feature=004-login-ui result=blocked pending=0 red=0 green=0 done=2 blocked=1 stopped_at=contract:A1:verify-red
```

Post-fix resume skip (new suite, test 2):

```
[run] contract:A1 verify-red -> skipped (still blocked since 2026-09-13T04:47:15.502Z)
run: feature=004-login-ui result=blocked pending=0 red=0 green=0 done=2 blocked=1 stopped_at=contract:A1:verify-red
```

## Residual Risks / Notes

- The change-signal probe is mtime-based against the verdict's
  `blocked_at` (the issue's own framing: "seam file, contract row,
  implementation"). A change that preserves every watched mtime (e.g. a
  same-timestamp touch) would be missed; the fail-open directions are
  pinned by tests (missing receipt, unreadable probes, gone seam file all
  re-drive).
- `lib/` is the watched implementation tree (the issue's target projects
  are Flutter/Dart apps); `bin/`-only CLI projects are not watched — out of
  the issue's named scope.
- Environment: this container hit a full `/tmp` (kernel dill dirs) during
  the first full-tree sweep; the affected files were re-run clean after
  housekeeping. All failures in that sweep were `No space left on device`
  load errors, none were assertion failures.
