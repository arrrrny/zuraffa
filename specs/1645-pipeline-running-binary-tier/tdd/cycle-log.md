# TDD Cycle Log — Spec 1645-pipeline-running-binary-tier (append-only)

## Baseline (pre-loop)

- Feature: specs/1645-pipeline-running-binary-tier (issue #1645, follow-up
  to #1643).
- Suite state before any behavior work: fast tier green on `master`
  (2ac6b9d7); the defect lives in the pipeline resolver's tier ORDER, not
  in missing code — the fix is a reorder, so reds are assertion reds, not
  load errors.
- Test list: 10 behaviors — 2 acceptance (A1, A2, assertion-red pre-fix),
  5 unit rows driven in this loop (U1–U3 new; U4/U5 re-shapes of the
  existing bug-#864 tier pins), 5 covered-existing (U6–U10, pinned by the
  verification pass).
- Driving toolchain: Dart 3.13.3 stable on macOS arm64; tests run scoped
  (per-file / services dir), never the whole repo (tdd-profile; issue
  #1642 TMPDIR hazard — this session pinned `TMPDIR` to the clone-local
  `.tmpdir/` for every run).

## Cycle C1 — the repro at the tier level (A1, A2 + guards U1–U3)

- **RED** (pre-fix, recorded before the fix):
  - `TMPDIR=.tmpdir dart test test/plugins/tdd/services/bug_1645_pipeline_running_binary_tier_test.dart`
    → `00:00 +3 -2: Some tests failed.`
    - A1 `Expected: '.../.tmpdir/zfa1645_cache*/zfa_exe'`
      `Actual:   '.../.tmpdir/zfa1645_path*/zfa'` — the PATH install won.
    - A2 same shape (stale-script driver) — the PATH install won.
  - U1 (B5), U2 (B3), U3 (B4) green pre-fix — the backward-compat guards
    and the outcome pin already held.
  - Classification: assertion red for the right reason (the resolver
    returns the PATH fixture; no compile errors).

## Cycle C2 — re-shape the synthetic VM stand-ins (U4, U5)

- U16/U17 in `pipeline_runner_test.dart` renamed their fake VM from
  `dart-vm` to the real VM name `dart` (labels renumbered tier 4/5).
- GREEN pre-fix: `dart test ... --plain-name "entrypoint auto-resolution"`
  → `00:04 +5: All tests passed!` — the honest shapes hold under the
  pre-fix order; they would have flipped red post-fix had they stayed
  synthetic (#1643 precedent).

## Cycle C3 — the fix (T101): green + regression scope

- **GREEN** step: `pipeline_runner.dart` — promoted tier 3 (the running
  binary: `!_isDartVmName(basename(resolvedExecutable)) && exists`,
  routed through the `compile` seam; non-`.dart` passes through
  unchanged), private `_isDartVmName` mirroring `StepRunner._isDartVmName`,
  docs renumbered (PATH → 4, fallback → 5) with the #1645 rationale.
- `dart test test/plugins/tdd/services/bug_1645_pipeline_running_binary_tier_test.dart`
  → `00:00 +5: All tests passed!`
- `dart test test/plugins/tdd/services/` → `03:41 +1103 ~1: All tests
  passed!` (includes the re-shaped bug-#864 tier group and every
  services neighbor)
- `dart test test/plugins/tdd/bug_1472_refactor_gate_acceptance_test.dart
  test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart` →
  `00:01 +18: All tests passed!` (FR-007: the pin untouched)
- `dart test test/core/no_jit_zfa_spawn_scan_test.dart` →
  `00:01 +5: All tests passed!` (the no-JIT sweep)
- `dart analyze` on the three changed files → `No issues found!`;
  `dart format` applied (2 files re-flowed, whitespace only) and the
  suite re-run green after formatting.
- Refactor pass: none needed beyond the format re-flow — the change is
  ordering + docs by design; no duplication introduced (the VM-name
  mirror is documented as deliberate in the plan/research).

## Cycle C4 — verify remediation (M2 + M4 survived pass 1, now killed)

- **Audit pass 1**: mutation sampling on the changed region — M1 killed
  (A1/A2), M3 killed (C1 red is exactly this state), M5 killed (by the
  re-shaped U16/U17), but M2 (dropped existence check) and M4 (bypassed
  compile seam) SURVIVED `+5: All tests passed!`. Verdict FAIL;
  remediation tasks R1–R3 appended to tasks.md.
- **Remediation**:
  - R1 → B6 (U11): missing non-VM-named executable falls through to PATH.
  - R2 → B7 (U12): a `.dart`-suffixed resolvedExecutable routes through
    the injected compile seam; the entrypoint is the artifact.
  - R3 → B3/B4 stand-ins became real existing VM files (`dart`,
    `dartaotruntime`) instead of `/usr/bin/*` paths.
- **Mutant re-run** (each applied to `pipeline_runner.dart`, `cmp`-restored):
  - M2 → `+6 -1` (B6 red) — KILLED
  - M4 → `+6 -1` (B7 red) — KILLED
  - M5 → `+5 -2` (B3/B4 red) — KILLED
- **GREEN**: bug_1645 suite `00:01 +7: All tests passed!`; services
  `04:31 +1105 ~1: All tests passed!`; #1472 + no-JIT `00:04 +23: All
  tests passed!`; `dart analyze` changed files: No issues found!;
  `dart format` applied, suite green after.
- Final audit verdict: PASS (5/5 mutants killed, one remediation pass).
