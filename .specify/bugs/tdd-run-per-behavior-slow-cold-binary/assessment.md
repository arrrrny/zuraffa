# Bug Assessment: fix(tdd): per-behavior U* tests are slow on cold binary — 5min per gen/verify-red/make cycle for unit plain-function behaviors

- **Slug**: tdd-run-per-behavior-slow-cold-binary
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/741
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

Running `zfa tdd run` on forklift spec 004 (49 behaviors) with all current fixes merged: each unit behavior takes ~5 minutes for the gen → verify-red → make cycle on a cold binary. With 39 U* behaviors still to process, the full run would take 3+ hours of pure wait time.

Issue URL: https://github.com/arrrrny/zuraffa/issues/741

## Symptom

Each U* behavior's `gen → verify-red → make` cycle takes ~5 minutes, dominated by full-suite `dart test` runs. The run is dominated by 39 sequential suite runs, making the full feature run take 3+ hours.

## Reproduction

Per-behavior timing on the post-#720 binary:
```
# U1: 5:30 (gen ~3s + verify-red ~2s + make ~5min with suite baseline)
# U2: 4:50
# U3: 4:35
# U4: 5:10
# U5: 5:25
# Average: ~5 min per U behavior
```

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/make_command.dart:247-273` — **confirmed**. Before generation, make runs a full-suite baseline via `runner.runSuite(suiteTemplate: suiteTemplate, workingDirectory: cwd)` (line 248). This is the dominant cost: `dart test` of the whole project (49 behaviors × stub compilation = large test tree).
- `lib/src/plugins/tdd/commands/make_command.dart:405-443` — **confirmed**. After generation, make re-runs the full suite (`guardRun`, line 411) and computes a `GuardDiff` (line 414-417). A second full-suite run per behavior.
- `lib/src/plugins/tdd/commands/verify_red_command.dart:179-184` — **confirmed**. verify-red already uses `runner.runSingle(singleTemplate: template, testPath: testPath, testName: testName)` — scoped to one test, not the full suite. So verify-red is NOT the bottleneck; the issue's "verify-red also runs the full suite" is a misattribution.
- `.specify/memory/tdd-profile.md:20-25` — **confirmed**. The profile defines `single: 'dart test {file} --plain-name "{name}"'` (scoped) and `suite: 'dart test'` (full repo). The profile explicitly notes: "Full suite (repo): `dart test` — slow; do not run for feature work, run the scoped subset instead."
- `lib/src/plugins/tdd/commands/run_command.dart:498` — the step order is `['gen', 'verify-red', 'make', 'refactor']`, sequential per behavior.

## Root Cause Hypothesis

The make command runs the full-suite baseline (and post-generation guard) once per behavior. With 39 U* behaviors, that's 78 full-suite `dart test` runs, each taking 1-3 minutes on this codebase. The profile itself warns that the full suite is "slow; do not run for feature work, run the scoped subset instead" — but make ignores that guidance and runs the full suite unconditionally.

The fix is not about correctness; it's about using the scoped test commands the profile already supports. High confidence: the code paths and profile text are verified directly.

## Proposed Remediation

**Preferred**: Cache the suite baseline across behaviors within a single run, and use scoped test commands where the full suite is not needed:

1. In `run_command.dart`, cache the full-suite baseline snapshot once per feature (or per run) and reuse it for every behavior's make step, instead of re-running `dart test` per behavior.
2. In `make_command.dart`, when the behavior's own test already passes (the #694 skip transition), skip the full-suite baseline and guard entirely — use only the scoped single-test run (`dart test <file> --plain-name "<name>"`).
3. For the post-generation guard, compare scoped single-test results where possible; only fall back to the full suite when the scoped run is inconclusive.

**Alternatives**:
- Parallelize the per-behavior steps across multiple processes. Trade-off: changes the run's deterministic ordering and resume semantics; risky.
- Reduce the suite scope to `test/plugins/tdd/` (feature scope) instead of the full repo. Trade-off: still slow at 49 behaviors; partial win.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/run_command.dart` (baseline caching across behaviors)
- `lib/src/plugins/tdd/commands/make_command.dart` (skip full-suite baseline/guard on #694 skip transition)
- `lib/src/plugins/tdd/services/runner.dart` (optional: scoped suite template support)

**Tests to add or update**:
- A 5-behavior fixture completes in <5 min total (currently ~25 min) with the baseline cached.
- The #694 skip transition (already-green behavior) does not run the full suite at all.
- Resume after interruption still works with the cached baseline.

## Risks & Considerations

- Caching the baseline across behaviors means a behavior's generation that introduces a NEW failure in a later behavior's test would not be caught until that later behavior's own make step. The per-behavior guard must still run scoped single-test checks to preserve the regression signal.
- Skipping the full suite on the #694 skip transition weakens the "whole suite is green" guarantee for skipped behaviors; the full suite should still run once per feature at the end (or per phase).
- This is a performance fix, not a correctness fix; it must not change any exit codes, summary lines, or evidence contracts.

## Open Questions

- [NEEDS CLARIFICATION: Should the full-suite baseline be cached per-feature or per-run? Does the run driver already have a mechanism to share state across behaviors?]
- [NEEDS CLARIFICATION: Is the full suite still required as a final gate per feature, or can it be dropped entirely in favor of scoped checks?]