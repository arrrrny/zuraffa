# Red Evidence — bug 720 (tdd-run-clean-state-skips-gen)

- **Date**: 2026-09-01
- **Branch**: fix/720-tdd-run-clean-state-skips-gen (at d6f7f517, pre-fix)
- **Binary**: real `zfa` compiled from `bin/zfa.dart` (Dart 3.13.3)

## Reproduction (matches issue #720)

Prior interrupted run simulated with the real binary on a scratch project
(`returns 42 when computed`, unit behavior):

1. `zfa tdd gen A1` → ok (artifacts.json + test/tdd/a1_test.dart + lib/tdd/a1_subject.dart)
2. `zfa tdd verify-red A1` → certified (red evidence appended to cycle-log.md)
3. Clean-state wipe: `rm run-state.json artifacts.json test/tdd/a1_test.dart lib/tdd/a1_subject.dart`
   (cycle-log.md retained — the residual red evidence; no in-flight marker was ever written)

## RED output (pre-fix)

```
$ zfa tdd run 990-bug720-repro --project . --zfa-bin zfa
zfa tdd run: feature 990-bug720-repro — 1 behavior(s)
[run] A1 make -> runner-error
zfa tdd run: step failed — behavior=A1 step=make outcome=runner-error
   zfa tdd make: behavior "A1" is planned in the 990-bug720-repro test list but has no gen artifacts. Run `zfa tdd gen A1` first.
   make: behavior=A1 outcome=runner-error feature=990-bug720-repro
   resume: fix the failing step, then re-run `zfa tdd run 990-bug720-repro`
run: feature=990-bug720-repro result=runner-error pending=0 red=1 green=0 done=0 stopped_at=A1:make
EXIT=2
```

The driver skipped `gen` and `verify-red` and went straight to `make`,
which failed resolution with "no gen artifacts" — the issue #720 symptom.

## Failing unit tests (pre-fix)

`dart test --preset=all test/plugins/tdd/run_command_test.dart --plain-name "bug 720"`
→ 3 failing (all new bug-720 regression tests), actual invocation sequences
starting `make B-001` with gen/verify-red skipped.
