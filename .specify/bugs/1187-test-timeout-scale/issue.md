# Bug 1187 — default 30s test / 75s subprocess timeouts fail wholesale on older hardware (feature_flags suite)

- **Severity:** medium
- **Reported by:** GitHub issue #1187 (2019 Intel Mac baseline)
- **Status:** fixed on branch `fix/1187-test-timeout-scale`

## Symptom

A full `dart test` on the 2019 Intel Mac failed 9+ tests in the
`test/feature_flags/` suite purely on timeouts — no logic failures:

```text
TimeoutException after 0:00:30.000000: Test timed out after 30 seconds.
TimeoutException after 0:01:15.000000: zfa subprocess exceeded its 75s child timeout:
  dart …/bin/zfa.dart make ProAnalytics di --no-entity   (test/helpers/run_zfa_source.dart)
  dart …/bin/zfa.dart feature list …
```

Every spawned `dart bin/zfa.dart …` pays the cold-frontend-server compile
cost per process; on this hardware that alone eats the 75s child budget and
the 30s test budget. Whole suites go red for environment reasons → noise
that hides real failures (and erodes trust in red). Agents/CI on modest
runners see the same.

## Root cause

Two hard-coded budgets in the shared helper
(`test/helpers/run_zfa_source.dart`) cannot stretch for slow hardware, and
the suite ceilings around them are fixed constants:

1. **75s child guard** — `runZfaSource` defaulted to
   `const Duration(seconds: 75)`. A cold source-fallback spawn
   (`dart bin/zfa.dart …`) on the 2019 Intel Mac exceeds it → the observed
   `TimeoutException after 0:01:15.000000`.
2. **100s AOT compile budget** — `_buildZfaExeIfPossible` bounded
   `dart compile exe` to `const Duration(seconds: 100)`. When the compile
   exceeds it, the build fails and every subsequent spawn in the file
   silently downgrades to the slow JIT fallback path (1), multiplying the
   failures.
3. **Fixed suite ceilings** — `build_flavor_filter_test.dart` declared
   fixed `const Timeout(Duration(minutes: 3))`; the other subprocess
   files relied on `dart_test.yaml` tag factors (`4x` for `slow`) which
   cannot grow with the child guard (and, per the issue's 30s log lines,
   historically sat far lower). Worst case in the suite is two sequential
   spawns (A3: disable + list) = 2 × 75s = 150s against a 120s ceiling.

An experimental probe (scratch test, since removed) confirmed the wiring
constraint: in the installed package:test version, group/test-level
`timeout:` declarations do NOT govern `setUpAll` bodies — so the AOT
compile window inside `setUpAll(initZfaSourceBin)` is bounded only by the
helper's internal compile guard. That guard is therefore the single lever
that must scale.

## Fix

Read a `ZFA_TEST_TIMEOUT_SCALE` environment multiplier (default 1.0,
clamped to ≥ 1.0, invalid/NaN/infinite → 1.0) once per isolate in
`test/helpers/run_zfa_source.dart` and scale every budget proportionally:

- `zfaDefaultChildTimeout` = 75s × scale — effective `runZfaSource` default
  (nullable `timeout` parameter, since the scaled budget is not a
  compile-time constant; explicit call-site budgets are unchanged).
- `zfaCompileTimeout` = 100s × scale — AOT compile budget.
- `scaleDuration(...)` exposed for suites; the `feature_flags` suite's
  `Timeout` declarations (3-minute base) now go through it, so enclosing
  ceilings grow together with the child guard at any scale.

Semantics unchanged: every test asserts exactly what it asserted before;
only time budgets move. All three `feature_flags` files that spawn
subprocesses already carried `@Tags(['slow'])`, so the fast tier (which
excludes `slow`) stays meaningful without new tags.

Documented for operators in `test/README.md` ("Slow machines:
`ZFA_TEST_TIMEOUT_SCALE`"), including the note that `dart_test.yaml` tag
factors cannot read the environment and out-of-suite users can pair the
scale with a `--timeout xN` flag.

## Verification

See `tdd/verification.md` in this directory. Red → green evidence in
`tdd/cycle-log.md`; behavior map in `tdd/test-list.md`.

## Related

- #1159 family (deadline plumbing), #1035 (gate severity policy), #531
  (child-guard / group-timeout invariant), #644 (AOT build race).
