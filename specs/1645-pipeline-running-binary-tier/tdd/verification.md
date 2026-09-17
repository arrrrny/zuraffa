# TDD Verification — Spec 1645-pipeline-running-binary-tier

**Audited**: 2026-09-15 (cold-context audit, LLM-guided — repo not zfa-wired)
**Verdict: FAIL (pass 1) → remediation → see final verdict below**

## Phase 1 — Test-first evidence

Source: `tdd/cycle-log.md` (reds recorded before their fixes; per the
tdd-profile convention the red test and its fix share one commit).

| Behavior | Red evidence | Green evidence |
| -- | -- | -- |
| A1 | assertion red, C1: `+3 -2` — `Expected: '.../zfa1645_cache*/zfa_exe'`, `Actual: '.../zfa1645_path*/zfa'` (the PATH install won) | C3 `+5` |
| A2 | assertion red, C1 (same run, stale-script shape) | C3 `+5` |
| U1 (B5) | none — GUARD, green pre-fix (outcome pin) | C1 `+3`, C3 `+5` |
| U2 (B3) | none — GUARD, green pre-fix | C1 `+3`, C3 `+5` |
| U3 (B4) | none — GUARD, green pre-fix | C1 `+3`, C3 `+5` |
| U4 (U16 re-shape) | none — shape-honesty fix, green pre-fix with the real VM name | C2 `+5` (group), C3 services `+1103` |
| U5 (U17 re-shape) | none — same | C2, C3 |
| U6–U10 | covered-existing (pinned by the suites below, not new tests) | C3: #1472 `+18`, no-JIT `+5`, services `+1103` |

The defect is an ORDERING defect in existing code — no new API surface —
so assertion reds (not load-error reds) are the honest red class, and the
guards are green-by-design pre-fix. Recorded as such in the test list.

## Phase 2 — Test-smell rubric

- Every failing assertion carries `reason:` naming the hazard; no bare
  expects.
- No sleeps/time waits; the single-step plans spawn real `#!/bin/sh`
  fakes that exit 0 — bounded, deterministic.
- Per-test temp dirs, torn down via `addTearDown`; no cross-test coupling;
  no platform facts read (all injected through the `runPlan` seams — the
  tests are hermetic even though production reads `Platform.*`).
- Fast tier only: no real `dart compile exe` anywhere (the default
  `ensureCompiled` passes the non-`.dart` fakes through unchanged —
  verified in `zfa_executable.dart` L187).
- No test doubles the SUT: the fakes replace only the compiled binaries
  standing in for the driver/PATH installs, never the resolver.

No material smells.

## Phase 3 — Mutation sampling (rubric fallback; no CI mutation gate)

Changed region: the promoted tier + `_isDartVmName` in
`pipeline_runner.dart`. One mutant at a time, `cmp`-restored after each.

| Mutant | Change | Result |
| -- | -- | -- |
| M1 | invert the VM-name check (`!_isDartVmName` → `_isDartVmName`) | **killed** — `+3 -2` (A1/A2 red) |
| M2 | drop the existence check (promote on name alone) | **SURVIVED** — `+5`: no test drives a non-VM-named executable that does NOT exist on disk (spec edge case; FR-001 "exists on disk") |
| M3 | demote the tier below PATH (the pre-fix order, simulated as `false &&` class) | **killed** — C1 red evidence is exactly this state; A1/A2 `+3 -2` |
| M4 | bypass the compile seam in the promoted tier (return the raw candidate) | **SURVIVED** — `+5`: no test pins the seam routing on the new tier (FR-005) |
| M5 | shrink the VM-name set to `{'dartvm'}` | **killed** — `+18 ~1 -2`: the re-shaped U16/U17 (real VM name `dart`, existing file) catch it — the re-shape made the name set testable |

Pass-1 score: 3 killed, 2 survived, 0 timed out.

## Phase 4 — Acceptance-criteria coverage

| SC | Evidence |
| -- | -- |
| SC-1 compiled driver resolves/spawns the driving binary | A1, A2 (red→green), U1 |
| SC-2 VM-driver behavior identical; re-shaped tier pins honest | U2, U3, U4, U5; services suite `+1103` |
| SC-3 regression + static scope green, zero new analyzer findings | #1472 `+18`, no-JIT `+5`, `dart analyze` changed files clean, `dart format` applied |

## Gate verdict — pass 1

**FAIL (exit 1 class)** — M2 and M4 survived: two untested facets of the
promoted tier (the existence-check fall-through; the compile-seam
routing). Remediation tasks appended to `tasks.md` (Phase 4: TDD
remediation — R1/R2/R3), driven through the loop, then re-audited.

## Remediation pass (pass 2)

- R1 → B6 (kills M2): non-VM-named resolvedExecutable MISSING from disk +
  PATH install → the PATH install wins (tier must not fire on a missing
  file). Red under M2 (`entrypoint` = the missing path), green under the
  fix.
- R2 → B7 (kills M4): the promoted tier routes a `.dart`-suffixed
  resolvedExecutable through the `ensureCompiled` seam — the injected
  fake records the candidate and the entrypoint is the returned artifact,
  never the raw source. Red under M4, green under the fix.
- R3 → U2/U3 strengthened: their VM stand-ins become REAL existing
  executable files named `dart` / `dartaotruntime` (the same shape-honesty
  as U16/U17), so the bug_1645 suite alone kills M5-class mutants without
  leaning on `/usr/bin/*` existing on the host.

Re-run after remediation:

| Mutant | Result |
| -- | -- |
| M2 | **killed** — B6 red under the mutant |
| M4 | **killed** — B7 red under the mutant |
| M5 | **killed** — B3/B4 now bite directly (existing VM fixtures) |

Suites after remediation: bug_1645 suite `+7`, services `+1105 ~1`,
#1472 + no-JIT combined `+23` — all green; `dart analyze` on the changed
files: `No issues found!`; `dart format` applied (whitespace re-flow in
the new tests) and the suite re-run green after formatting.

## Final gate verdict

**PASS** — TDD discipline proven (per-behavior red→green evidence, guards
green-by-design recorded honestly), mutation sampling 5/5 killed after one
remediation pass, acceptance criteria covered, regression scope green.
