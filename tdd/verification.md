# tdd.verify — Bug #1544 run parks forever on first blocked contract

- **Verified**: 2026-09-13, this session, on
  `fix/1544-parks-forever-on-first-blocked-contract` (working tree, pushed)
- **Toolchain**: Dart 3.13.3 (stable) on linux_x64
- **Scope**: `lib/src/plugins/tdd/commands/run_driver_core.dart` + the new
  `test/plugins/tdd/commands/bug_1544_run_continue_after_blocked_test.dart`,
  then the chunked regression sweep below.

## Verdict: PASS (with the recorded host/environment caveats in §5)

## 1. Static analysis

```
dart analyze lib/src/plugins/tdd/commands/run_driver_core.dart \
             test/plugins/tdd/commands/bug_1544_run_continue_after_blocked_test.dart
→ No issues found!

dart analyze            (whole repo)
→ 112 issues found      (all `info`)
→ errors/warnings: 0    (baseline: 0 — no new warnings)
```

The whole-repo count is byte-identical to the pre-change baseline (112 info
lints, 0 errors, 0 warnings).

## 2. The bug suite (REAL runs in this session)

```
dart test test/plugins/tdd/commands/bug_1544_run_continue_after_blocked_test.dart
→ 00:08 +6: All tests passed!
```

REQUIRED checks — the issue's two expected behaviors are PROVED by real
runs, not inspection:

- **Continue past blocked (A-1544-a1)**: with `contract:A1` scripted
  `verify-red -> blocked` and `contract:A2`/`contract:A3` defaulting green,
  the single `tdd run` spawn log contains
  `verify-red contract:A1 → gen contract:A2 → verify-red contract:A2 →
  make contract:A2 → gen contract:A3` IN ORDER, never `make contract:A1`,
  and the summary line reads
  `run: feature=004-login-ui result=blocked pending=0 red=0 green=0 done=2 blocked=1 stopped_at=contract:A1:verify-red`
  with exit code 1. Persisted state: A1 `blocked`, A2/A3 `done`.
- **Resume skip with receipt (A-1544-a2)**: run 2 (same fixture, seeded
  `contract-blocked.A1.json` with `blocked_at = now-1h`, seam file and
  test-list mtimes `now-2h`) prints
  `[run] contract:A1 verify-red -> skipped (still blocked since 2026-09-13T…)`,
  spawns NO step for A1, stops `result=blocked blocked=1`, and leaves the
  state honestly blocked.
- **Fail-open (A-1544-a3/a4/a5)**: seam file newer than the verdict, lib/
  source newer than the verdict, and a missing receipt each re-drive
  `verify-red contract:A1` (the unblock path preserved).
- **Non-blocked resume guard (A-1544-b1)**: with U1 seeded red and A1
  blocked-unchanged, the resume spawns `make U1` AND prints the A1 skip
  receipt — both resume windows work in one run.

## 3. RED evidence (pre-fix)

The same suite against the unmodified driver failed 3/6:

```
A-1544-a1  [E]  Expected: contains 'gen contract:A2' (in order after verify-red contract:A1)
                Actual: run stopped at contract:A1 — stepInvocations ended at
                [gen contract:A1, verify-red contract:A1]
A-1544-a2  [E]  Expected: contains 'contract:A1 verify-red -> skipped (still blocked since'
                Actual: '[run] contract:A1 verify-red -> blocked' — re-attempted
A-1544-b1  [E]  same skip-receipt absence
```

— exactly the reported symptoms (A2 unreachable; resume re-attempting A1).

## 4. Regression sweep (chunked, real runs)

```
dart test test/plugins/tdd/commands
→ 03:38 +539: All tests passed!

dart test test/plugins/tdd/services
→ 02:04 +935: All tests passed!

dart test test/plugins/tdd/*.dart            (halves)
→ +186: All tests passed!
→ +333: All tests passed!
```

Targeted neighbor pin (the pre-#1544 contracts that must survive):

```
dart test contract_kind_1007_test.dart run_engine_command_test.dart \
         run_skin_command_test.dart run_command_bug_1471_test.dart \
         bug_1271_widget_lane_engine_deferral_test.dart \
         bug_1373_scaffolded_hand_off_driver_test.dart \
         bug_1411_born_green_hand_transition_test.dart
→ +51: All tests passed!
```

The #1007 single-row pin still holds verbatim: one blocked contract stops
with `result=blocked`, `blocked=1`, `stopped_at=contract:A1:verify-red`,
exit 1, step log exactly `[gen contract:A1, verify-red contract:A1]` — for a
single-row list the end-of-pass terminal is indistinguishable from the old
mid-loop stop.

## 5. Host/environment caveats

- `/tmp` filled once during the first full-tree sweep (`No space left on
  device` while copying kernel dills — 123 LOAD errors, zero assertion
  failures). After housekeeping the previously-unloaded files were re-run
  clean (49/49). Keep `/tmp` swept when running the full tdd tree on a
  10 GB-disk agent.
- The container has no Flutter SDK; the `example/` package does not resolve
  (`flutter pub` required). Unrelated to this fix — no touched code path
  imports Flutter.
- `dart format` was applied to the two changed files only (formatting the
  whole repo is out of scope and would pollute the diff).
