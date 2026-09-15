# 1623-integration-timeout-budget

- **Spec ID**: 1623-integration-timeout-budget
- **Created**: 2026-09-15
- **Source**: GitHub issue #1623 (test/helpers: AOT build budget (100s) + 75s child guard are too tight for slow hosts — integration spawns time out)
- **Type**: test-infrastructure fix (P1 — integration suites fail on slow hosts with bare `TimeoutException`s instead of actionable diagnostics)
- **Branch**: feat/1623-integration-timeout-budget
- **Related**: #1187 (`ZFA_TEST_TIMEOUT_SCALE` — the designed slow-host knob), #531 (child-guard fail-fast + named `TimeoutException`), #644 (ETXTBSY atomic rename), #1615 (the hosted-lane constraint B9b pins), B9b test case (`test/package_sdk/plugin_scaffold_e2e_test.dart`)

## Problem

On the host that filed #1623, the B9b integration test times out with a bare
subprocess diagnostic instead of passing or failing with an actionable
message:

```
02:55 +0 -1: B9b: the hosted lane (no --zuraffa-path) stamps a constraint that resolves [E]
  TimeoutException after 0:01:15.000000: zfa subprocess exceeded its 75s child timeout:
  dart /private/tmp/fix-pr-1617/bin/zfa.dart package plugin hosted_plugin ...
```

Measured root cause on that host:

1. `dart compile exe bin/zfa.dart` takes **2m38s**; the AOT build budget is
   100s (`kZfaCompileBaseTimeout`), so the build is abandoned at its deadline
   and no compiled artifact exists.
2. The spawn then falls back to `dart bin/zfa.dart`, whose **cold JIT start
   alone is 1m24s** (`time dart bin/zfa.dart --version` → 84s) — longer than
   the 75s default child guard — before the command does any work.
3. `ZFA_TEST_TIMEOUT_SCALE` (#1187) is the designed knob for exactly this
   situation, but it was not set, and nothing in the failure path pointed the
   operator at it: the symptom is a bare subprocess timeout rather than a
   "slow host / AOT build unavailable" diagnostic.

State of the tree since the no-JIT spawn policy (#531 follow-up, commit
06ecc54 — landed AFTER the issue was filed):

- The AOT fallback is no longer silent: a compile that fails, times out, or
  produces no artifact throws `ZfaCompilationException`, and
  `initZfaSourceBin` rethrows it as a loud `StateError` (the file fails in
  `setUpAll` with the full diagnostic, never a degraded JIT suite).
- The default child guard already scales: `zfaDefaultChildTimeout` =
  75s × `ZFA_TEST_TIMEOUT_SCALE`, and the compile budget
  (`ZfaExecutable._compileTimeout`) already derives from the same env.
- What REMAINS on the issue's acceptance criteria:
  1. B9b still carries the workaround the issue describes as manual: an
     explicit `timeout: const Duration(seconds: 240)` on the scaffold spawn,
     plus a comment describing the pre-policy silent fallback that no longer
     exists. The budget the test needs belongs to the helper, computed from
     the scale — not hard-coded in the test body.
  2. The FIRST cold source spawn is still budgeted by the flat 75s guard.
     Under the documented degraded-environment escape hatch
     (`ZFA_ALLOW_JIT=1`, the only path that spawns `dart bin/zfa.dart`), a
     cold JIT start measured at 84s exceeds the 75s guard at scale 1.0 —
     the exact #1623 shape, still reproducible today.
  3. The compile-TIMEOUT variant of the loud diagnostic (the precise
     slow-host scenario: budget exhausted, child killed at the deadline)
     has no unit test pinning that its reason names the budget AND the
     `ZFA_TEST_TIMEOUT_SCALE` remedy — the exit-code and no-artifact
     variants are pinned (U6/U7), the timeout variant is not.
  4. `test/README.md` still documents the OBSOLETE silent fallback ("every
     spawn in the file silently downgrades to the slow `dart bin/zfa.dart`
     JIT path") — an operator reading it would misdiagnose a loud
     `StateError` as impossible, and the page carries no worked example for
     a slow CI host.

## Goal

Slow hosts fail LOUDLY with actionable budgets, never with bare subprocess
timeouts or silent degradations: the helper budgets the first cold source
spawn from a scaled cold-start base (240s — headroom over the measured 84s
cold JIT start), B9b drops its manual 240s override in favor of the helper's
scaled default, the compile-timeout diagnostic is pinned by a unit test to
name the scale knob, and the test README documents the current loud-failure
contract with worked slow-CI-host examples.

## Success criteria (measurable)

- **SC-1**: `test/package_sdk/plugin_scaffold_e2e_test.dart` B9b calls
  `runZfaSource` WITHOUT an explicit `timeout:` argument — the helper's
  scaled default governs — and the B9b test passes on this host
  (`dart test --preset=integration ... -n B9b` green). No assertion logic
  changes: the scaffold → constraint → pub get flow is byte-identical.
- **SC-2**: When the AOT compile cannot happen (failure, deadline, or no
  artifact), the failure is LOUD and actionable: the thrown
  `ZfaCompilationException` for a DEADLINE kill carries a reason naming the
  budget seconds and the `$kZfaTimeoutScaleEnv` remedy — pinned by a unit
  test (`ZfaCompilationException` reason contains `ZFA_TEST_TIMEOUT_SCALE`),
  and `runZfaSource` never spawns a JIT child unless `ZFA_ALLOW_JIT=1` is
  explicitly set (existing U6/U8/U10 pins stay green).
- **SC-3**: The first cold source spawn of a test isolate is budgeted at
  `scaleDuration(240s)` (new `kZfaColdSourceBaseTimeout` = 240s base, ≥ 240s
  at every valid scale) instead of the flat 75s guard, when the resolved
  entrypoint is a Dart source (the `ZFA_ALLOW_JIT=1` shape) and the caller
  passed no explicit timeout: pinned by fast-tier unit tests covering the
  full matrix — first source spawn → cold budget; later source spawns and
  every compiled-binary spawn → 75s default; explicit caller timeout wins
  and is NOT auto-scaled (existing documented semantics).
- **SC-4**: `test/README.md` documents the CURRENT contract: the AOT build
  failure is loud (no silent JIT downgrade — that stale sentence is
  removed), the 240s first-cold-source-spawn budget, and a worked
  `ZFA_TEST_TIMEOUT_SCALE` example for slow CI hosts (env in the job
  environment, plus the `--timeout xN` interplay with fixed
  `dart_test.yaml` tag ceilings).

## Hard constraints

- Fix test/helpers timeout budgeting ONLY: `test/helpers/run_zfa_source.dart`
  (budget derivation + spawn wiring), the B9b `timeout:` override removal
  (budgeting, not logic), `test/README.md`, and the unit tests that pin the
  behaviors. Do NOT change the integration test's assertion logic, the AOT
  compilation itself (`lib/src/cli/zfa_executable.dart` compile mechanics —
  its scale plumbing already works), or any production spawn path.
- The child guard must stay shorter than the enclosing test ceiling at
  scale 1.0: 240s cold budget < B9b's 6-minute `Timeout` and B9's 8-minute
  ceiling. Higher scales are the operator's explicit choice — the README
  already documents the `--timeout xN` companion for fixed tag ceilings.
- The scale can only RELAX budgets, never tighten them (≥ 1.0 clamp
  preserved everywhere, including the new cold budget).
- One PR, `Closes #1623`.

## Out of scope

- Changing `ZFA_TEST_TIMEOUT_SCALE` parsing/clamping semantics (#1187 —
  already specified and pinned by `zfa_test_timeout_scale_test.dart`).
- Touching `lib/` (the compile budget, lock, rename, and JIT-hatch policy
  are working as specified by #531/#644/#1187).
- Making the suite `Timeout` ceilings in `plugin_scaffold_e2e_test.dart`
  scale-aware (fixed const ceilings are the documented `dart_test.yaml`
  pattern; B9/B9b budgets fit inside them at scale 1.0).
- Retrying failed AOT builds with a larger implicit budget — the scale is
  the knob; silently longer builds would hide slow-host regressions.
