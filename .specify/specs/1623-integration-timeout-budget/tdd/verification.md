# Verification: 1623-integration-timeout-budget

- **Date**: 2026-09-15
- **Branch**: feat/1623-integration-timeout-budget
- **Base**: origin/master 26a6fc0 (Merge PR #1631)
- **Scope audited**: spec.md (SC-1..SC-4), plan.md design, tasks.md,
  tdd/test-list.md, tdd/cycle-log.md, changed code, changed tests.
- **Provenance**: every number below is from a REAL run in this session on
  the recorded command — nothing copied, stubbed, or back-dated.

## Verdict: VERIFIED for the #1623 fix surface — all four SCs proved;
one UNRELATED pre-existing master failure (B9b's #1615 version-const
assertion) is flagged, reproduced at base, and out of scope by the spec's
hard constraints.

## 1. Red evidence (recorded before implementation)

Source: `tdd/cycle-log.md` (append-only).

- command: `dart test test/helpers/zfa_test_timeout_scale_test.dart`
- result: `+0 -1: Some tests failed.` — file failed to LOAD with exactly 8
  analyzer errors (2x undefined `zfaColdSourceChildTimeout`, 6x undefined
  `resolveChildTimeout`): the API under test did not exist at HEAD. A
  syntax slip during test-writing (a consumed group brace) was caught by
  `dart analyze` and fixed BEFORE this entry — the recorded red is the
  intended undefined-API red, no parser noise.
- R5 (U11) declared a pin, run BEFORE implementation:
  `dart test test/cli/zfa_executable_test.dart` → `+19: All tests passed!`
  (green-before-write by design — the loud deadline diagnostic shipped in
  06ecc54, two days after #1623 was filed; recorded as a pin, not a
  fabricated red).

## 2. Green evidence (after implementation)

- change: `test/helpers/run_zfa_source.dart` ONLY (kZfaColdSourceBaseTimeout
  240s + scaled getter + pure `resolveChildTimeout` + spent-once wiring in
  `runZfaSource`).
- cycle: implementation (T002) → 2 mechanical slips caught by analyze
  (positional arg vs named parameter; redundant `!` after flow analysis) →
  fixed in-cycle, no test edited → **`+31: All tests passed!`**,
  `No issues found!` on all four changed Dart files.
- re-confirmed after `dart format`: `+31: All tests passed!` (post-format
  run, identical counts).
- scale plumbing both ways (README contract): `ZFA_TEST_TIMEOUT_SCALE=4
  dart test test/helpers/zfa_test_timeout_scale_test.dart` →
  **`+12: All tests passed!`** (expectations computed from the process
  env); unset run → `+12: All tests passed!`.

## 3. Test inventory (exact, real counts)

| suite | scale 1.0 | scale 4.0 | delta vs master |
| ----- | --------- | --------- | --------------- |
| test/helpers/zfa_test_timeout_scale_test.dart | 13/13 | 13/13 | +4 (R1–R4 + restored scaleDuration pin; see §9) |
| test/cli/zfa_executable_test.dart | 19/19 | n/a (no env dependence) | +1 (U11 pin) |
| combined | 32/32 | — | +5 (see §9) |

## 4. Success-criteria audit

| criterion | verdict | evidence |
| --------- | ------- | -------- |
| SC-1 B9b without manual timeout override | PASS (budget path proved end-to-end; full green blocked by an unrelated pre-existing assertion — see §5) | the `timeout: const Duration(seconds: 240)` argument is REMOVED (`git diff origin/master` shows the budget-only edit, zero assertion changes); the real B9b run on this host (`dart test --preset=integration test/package_sdk/plugin_scaffold_e2e_test.dart -n B9b`, 42s wall) PROVES the spawn path under the helper's scaled default: AOT build inside the 100s budget in setUpAll, scaffold spawn exit 0 under the helper budget, stamped constraint `^6.3.0` == what pub.dev serves (first assertion passed); the run then fails at the THIRD-party assertion `isNot('^$version')` — reproduced identically at base 26a6fc0 (§5), i.e. NOT introduced by this branch |
| SC-2 loud AOT failure diagnostic | PASS | U11 pin: a compile runner failing with `TimeoutException` → `ZfaCompilationException` (exit −1) whose reason contains `exceeded its`, `budget`, `ZFA_TEST_TIMEOUT_SCALE`; no artifact left on disk. Existing U6/U7/U8/U10 pins stayed green (no JIT fallback without the hatch). README now documents the loud contract |
| SC-3 first cold source spawn scaled budget | PASS | R1: `zfaColdSourceChildTimeout` == 240s × scale, ≥ 240s (red→green); R2: first source spawn spends the cold budget (red→green); R3: later source spawns + compiled spawns spend the 75s default (red→green); R4: explicit timeouts returned verbatim, never auto-scaled (red→green); wiring proven by analyze + the real B9b run |
| SC-4 documentation | PASS | test/README.md: stale "silently downgrades" sentence REPLACED with the loud-failure contract; new 240s cold-source budget bullet; worked slow-CI-host example (GitHub Actions `env:` shape + `--timeout xN` interplay + one-off repro command) |

## 5. Unrelated pre-existing failure (flagged, not fixed)

B9b fails at its third assertion (`plugin_scaffold_e2e_test.dart:165`):

```
Expected: not '^6.3.0'
  Actual: '^6.3.0'
the dev version const is the next unreleased release — the very
constraint pub rejects (issue #1615)
```

Root cause: `lib/src/version.dart` still has `const version = '6.3.0'`
while pub.dev serves 6.3.0 as latest — the dev const was not bumped after
the 6.3.0 release, so the #1615 guard ("stamped constraint must not be the
dev version") cannot hold. **Reproduced at base commit 26a6fc0 in a clean
worktree** (`git worktree add /tmp/zuraffa-base origin/master`): identical
failure, 47.9s wall — pre-existing on master, independent of this branch.
Fixing it would change release metadata + integration test expectations —
outside this spec's hard constraints ("fix test/helpers timeout budgeting
only", "one PR per feature"). Recommend a separate release-hygiene PR that
bumps the dev const to 6.4.0 (or wherever the next release lands).

## 6. Constraint audit

- **Fix surface**: `git diff origin/master -- lib/` is EMPTY — no
  production code changed (the AOT compilation, compile budget derivation,
  lock/rename mechanics untouched). Changed files: the helper, the B9b
  budget-only edit, the README, the two test files, plus spec artifacts.
- **Guard-inside-ceiling preserved at scale 1.0**: 240s cold budget <
  B9b's 360s `Timeout` and < B9's 480s ceiling (constant value asserted by
  R1's clamp direction; the ceilings are const in the integration file and
  untouched).
- **Scale only relaxes**: every new budget routes through
  `scaleDuration` / the ≥1.0 clamp (R1 pins ≥ 240s; the pre-existing #1187
  pins for 75s/100s stayed green).
- **Explicit budgets not auto-scaled**: R4 pins the documented verbatim
  passthrough; B9's per-package budgets live on a local `_runSupervised`
  and were not touched.

## 7. Analysis + format gates

- `dart analyze` on all four changed Dart files: `No issues found!`
- `dart format --output=none --set-exit-if-changed .`: **Formatted 2864
  files (0 changed)** — zero remaining formatting diffs repo-wide
  (the `example/` flutter_lints include warning is the Flutter-SDK absence
  on this agent; unrelated to format state).
- Kernel-cache hygiene per protocol: `.dart_tool/test/` +
  `dart_test.kernel.*` removed before test batches; worktree removed after
  the base reproduction; disk stayed ≥ 8.2G free throughout.

## 8. What was NOT proved

- B9b's full green run end-to-end is blocked on master by the §5
  version-const failure (present at base, proven). Everything UP TO that
  assertion — the entire #1623-relevant path (AOT build inside budget,
  spawn under the helper's scaled default, pub.dev lookup, constraint
  stamp, constraint resolution via `dart pub get`) — passed in the real
  run.
- The JIT-hatch cold spawn was not exercised with a REAL cold `dart
  bin/zfa.dart` child on this host (that requires `ZFA_ALLOW_JIT=1` and a
  deliberately degraded environment); its budget DECISION is pinned by the
  R1–R4 matrix, and the real spawn path was exercised through the AOT lane.

## 9. Review-fix round (PR #1638 review findings)

- Finding "scaleDuration proportionality pin deleted": the master pin is
  RESTORED inside `group('scaled budgets')` (same expectation shape as
  master, computed from the live process scale). Suite count 12 → 13;
  §3's "delta vs master: +4" is again exact.
- Finding "spent-once model rests on an unverified warm-start assumption":
  MEASURED on this host — after a warm-up run, `time dart bin/zfa.dart
  --version` → **1m11.252s warm** (the warm-up run itself: 57.8s; the
  #1623 host was slower, 84s cold). 71s warm against the 75s default
  guard invalidates the spent-once model, so per the review's decision
  rule the stronger fix landed: `resolveChildTimeout` now budgets EVERY
  source spawn at `zfaColdSourceChildTimeout`; the `coldBudgetAvailable`
  parameter and the isolate-global `_zfaColdSourceBudgetSpent` flag are
  removed (source spawns exist only under `ZFA_ALLOW_JIT=1`, so the CI
  AOT lane is untouched). R2/R3 re-landed for the new contract; the
  README bullet, slow-CI example, and test-list rows updated to match.
- Nitpick applied by supersession: the spent-once mark line
  (`if (coldBudgetAvailable && timeout == null) ...`) is gone entirely
  with the flag.
- Out-of-scope speckit re-install churn REVERTED to master:
  `.agents/skills/speckit-tdd-plan/SKILL.md`,
  `.specify/templates/spec-template.md`, `.specify/init-options.json`,
  `.specify/integrations/zed.manifest.json` (the PR's own spec artifacts
  under `.specify/specs/1623-integration-timeout-budget/` are untouched).
- Evidence (this round, this host): `dart analyze` on the touched Dart
  files → `No issues found!`; scale suite → **13/13** unset and **13/13**
  with `ZFA_TEST_TIMEOUT_SCALE=4`; executable suite → **19/19**;
  `dart format --output=none --set-exit-if-changed` on the touched files
  → 0 changed after one canonical-format pass.
