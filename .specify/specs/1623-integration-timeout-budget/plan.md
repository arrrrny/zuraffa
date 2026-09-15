# Plan: 1623-integration-timeout-budget

- **Spec ID**: 1623-integration-timeout-budget
- **Created**: 2026-09-15

## Technical Context

- **The spawn helper**: `test/helpers/run_zfa_source.dart` — every
  integration suite's subprocess entrypoint. Budget plumbing that already
  works (#1187, commit 06ecc54):
  - `parseTimeoutScale(String?)` (:29) — the pure ≥1.0-clamping parser.
  - `zfaTestTimeoutScale` (:47) — read once at isolate start.
  - `scaleDuration(Duration)` (:57) — the stretch primitive.
  - `zfaDefaultChildTimeout` (:62) — 75s × scale, the effective default
    child guard for `runZfaSource`.
  - `zfaCompileTimeout` (:69) — mirrors the lib compile budget.
  - `runZfaSource(...)` (:148) — resolves `zfaExePath`, computes
    `childTimeout = timeout ?? zfaDefaultChildTimeout` (:160), shapes the
    argv through `ZfaExecutable.commandFor` (:164), and supervises the
    child through `_runSupervised` (kill-on-timeout with a named
    `TimeoutException` diagnostic, :257).
- **The cold source spawn that still gets the flat guard**: under the
  documented degraded-environment hatch (`ZFA_ALLOW_JIT=1`), `ensureCompiled`
  returns the `.dart` candidate unchanged (lib `zfa_executable.dart:189-196`)
  and `commandFor` shapes `['dart', entry, ...args]` (:149). `runZfaSource`
  then budgets that cold JIT child with the SAME 75s guard as an
  AOT-millisecond child — but the issue measured the cold JIT start alone
  at 84s (`time dart bin/zfa.dart --version` → 1m24s). The helper already
  knows which shape it is holding: `ZfaExecutable.isDartScript(exe)`
  (lib :133) — the budget choice just never consults it.
- **The manual override to remove**: B9b
  (`test/package_sdk/plugin_scaffold_e2e_test.dart:123-138`) passes
  `timeout: const Duration(seconds: 240)` with a comment describing the
  pre-policy silent fallback. Under the no-JIT policy that comment is false
  (there IS no fallback — a failed build throws in `setUpAll`), and the
  hard-coded 240s ignores the scale mechanism entirely. The spawn needs no
  explicit budget on a healthy host (AOT spawn ≈ ms) and the scale governs
  the degraded path — the override is pure workaround debt.
- **The diagnostic to pin**: `ZfaExecutable._compileCached`
  (lib :326-343) wraps the compile child in
  `.timeout(_compileTimeout(environment))`; `on TimeoutException` throws
  `ZfaCompilationException(reason: 'dart compile exe exceeded its Ns budget
  (raise it with ZFA_TEST_TIMEOUT_SCALE)')`. U6 (exit-code failure) and U7
  (no artifact) are pinned in `test/cli/zfa_executable_test.dart`; the
  DEADLINE variant — the exact #1623 slow-host scenario — is not. A fake
  compile runner that fails with `TimeoutException` exercises the catch
  without waiting out a real 100s budget (the runner's error propagates
  through the same `await ... .timeout(...)` expression into the same
  handler).
- **The docs to correct**: `test/README.md` "Slow machines:
  `ZFA_TEST_TIMEOUT_SCALE`" section still says the AOT budget miss makes
  "every spawn in the file silently downgrade to the slow `dart bin/zfa.dart`
  JIT path" — pre-policy text (06ecc54 removed that path). The same section
  lacks the cold-source budget and a worked slow-CI-host example.
- **The ceiling relationship**: the child guard must stay shorter than the
  enclosing test ceiling for the fail-fast diagnostic to fire first
  (`run_zfa_source.dart:166-177`). B9b declares `Timeout(6min)` (360s), B9
  declares `Timeout(8min)` (480s) — both const. 240s cold budget < 360s at
  scale 1.0 ✓; at scale ≥ 1.5 the operator is explicitly stretching budgets
  and the README's existing `--timeout xN` companion guidance applies (the
  same trade-off the feature_flags suites document).

## Design

1. **Cold-source budget derivation** (helper, ~30 lines):
   - `kZfaColdSourceBaseTimeout = Duration(seconds: 240)` — the base budget
     for the first cold source spawn: headroom over the measured 84s cold
     JIT start (≈2.9×), and the same number the B9b workaround reached for
     by hand. Below the 360s/480s const ceilings at scale 1.0.
   - `zfaColdSourceChildTimeout` — `scaleDuration(kZfaColdSourceBaseTimeout)`:
     scales with `ZFA_TEST_TIMEOUT_SCALE`, ≥ 240s at every valid scale
     (the scale relaxes, never tightens — same invariant as the 75s/100s
     budgets).
   - `resolveChildTimeout({Duration? explicit, required bool sourceSpawn,
     required bool coldBudgetAvailable})` — the pure budget resolver the
     spawn site calls, unit-testable without a subprocess:
     explicit (caller-passed) → returned verbatim, never auto-scaled
     (documented semantics preserved); source spawn with the cold budget
     still available → `zfaColdSourceChildTimeout`; otherwise →
     `zfaDefaultChildTimeout`.
2. **Spawn wiring** (`runZfaSource`): `final sourceSpawn =
   ZfaExecutable.isDartScript(exe)`; budget =
   `resolveChildTimeout(timeout, sourceSpawn: sourceSpawn,
   coldBudgetAvailable: !_zfaColdSourceBudgetSpent)`; when the resolver
   picked the cold budget (no explicit timeout, source spawn, first),
   set `_zfaColdSourceBudgetSpent = true`. The flag is isolate-global like
   `zfaExePath` (one `initZfaSourceBin` per test file → one cold start per
   isolate; later spawns ride warm OS/VM caches inside the 75s guard).
3. **B9b override removal**: drop the `timeout:` argument and replace the
   stale pre-policy comment with the current contract (helper budgets; the
   scale governs slow hosts). Zero assertion changes.
4. **Diagnostic pin** (`test/cli/zfa_executable_test.dart`, next to U6):
   a compile runner that fails with `TimeoutException` →
   `ZfaCompilationException` whose reason contains the budget language and
   `kZfaTimeoutScaleEnv`, exit code `-1`.
5. **README rewrite** of the stale paragraph + new bullets (cold-source
   budget, loud-failure contract) + a slow-CI-host worked example
   (GitHub Actions `env:` block shape, and the `--timeout xN` interplay
   with fixed `dart_test.yaml` tag ceilings).

## Risks / trade-offs

- **Cold budget vs const ceilings at high scale** — documented, not solved
  in code: the helper cannot know the enclosing ceiling, and silently
  capping the scale would defeat the knob. README states the companion
  `--timeout xN` for scales that push a budget past a fixed ceiling.
- **`_zfaColdSourceBudgetSpent` mutable top-level state** — matches the
  helper's existing isolate-global pattern (`zfaSourceBin`, `zfaExePath`);
  the DECISION is kept pure (`resolveChildTimeout`) so tests never touch
  the mutable flag.
- **JIT-hatch-only impact** — the AOT path (everything without
  `ZFA_ALLOW_JIT=1`) is behaviorally unchanged; the cold budget exists for
  the degraded lane and the #1623 reproduction shape.

## Test strategy

Fast-tier, subprocess-free unit tests (house rule: helpers tests never
spawn): the budget matrix in `test/helpers/zfa_test_timeout_scale_test.dart`
(R1–R4) and the timeout-diagnostic pin in
`test/cli/zfa_executable_test.dart` (R5). AC-1's end-to-end proof is the
real B9b run on this host without the override, recorded verbatim in the
verification artifact. Red evidence: R1–R4 reference API that does not
exist yet (compile-error red), R5 is a regression pin for behavior 06ecc54
already shipped (green-before-write by design — recorded as a pin, not a
fabricated red, per the 1505 honesty convention).
