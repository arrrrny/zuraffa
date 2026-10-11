## Symptom

The `dart_core` CI job (`.github/workflows/ci.yaml`, pure-Dart lane `dart test test --exclude-tags "flutter || e2e"`, `timeout-minutes: 30`) is cancelled at exactly ~30m14s on every recent run, so the pure-Dart suite is silently skipped for the whole PR/merge gate. Expected: the lane completes and passes within its budget (goal: test step below 8 minutes).

## Reproduction

1. Push any commit to `master` or a PR branch (evidence: run 34951330675, master, 2026-09-15T09:13Z).
2. Observe the `dart_core` job: started 09:13:20, cancelled 09:43:39 (~30m19s) — `##[error]The operation was canceled.` during "Dart Test (pure Dart, no Flutter)".
3. 12 of the last 15 ci.yaml runs have `dart_core: cancelled` at ~30:14; runs where the lane finished are `failure` runs that still took 28m49s–29m46s (e.g. 34936969400). All eight sibling jobs pass in ≤ 24 minutes.

## Evidence (run 34951330675 job log)

- Test step ran 09:14:01 → 09:43:34 and **never finished**: 6,962 tests across 1,037 suites completed, killed mid-`test/cli/writers/tdd/bug_1349_init_flutter_app_deps_test.dart`.
- **57 fast-lane-eligible suites never ran at all** (test/cli/standard ×11, `test/agent/**` ×23, `test/skew`, …) — true full-lane duration > 30 min.
- No single monster test (largest inter-completion gap 32.1s; top file `test/commands/dead_positional_grammar_test.dart` 80.1s — spawns the real CLI). The time is a long tail of heavyweight suites + per-suite kernel compile (silent stretches ≥5s total 790s = 45%):
  `test/plugins/tdd/commands` 383.5s · `test/commands` 257.1s · `test/plugins/tdd` 192.7s · `test/plugins/tdd/services` 131.9s · `test/templates/self_hosting` 102.4s · `test/skin` 46.7s · `test/plugins/mock` 43.0s
- 75 suites that ran directly spawn external processes and account for 582s.
- The `slow` exclusion works — zero `@Tags(['slow'])` files appear in the log. The lane is overfull with **never-tagged** heavy suites.
- ci.yaml:43's "this job runs at ~22 of its 30 budgeted minutes" is stale.

## Suspected Code Paths

- `.github/workflows/ci.yaml:15-45` — `dart_core` job; stale budget comment; serial execution (`concurrency: 1` from `dart_test.yaml`, introduced for heavy temp-project lanes, not the pure-Dart unit lane).
- ~116 never-tagged heavyweight suites (run-driver, grammar sweeps, skin VmTap driver, self-hosting analyzer/compile gates, corpus economics) + 57 untagged cut-off suites.
- 8 regression files tagged `@Tags(['regression'])` without `slow` — small leak violating the documented tier invariant.

## Root Cause Hypothesis

The fast lane was scoped when the pure-Dart suite fit (~22 min per the stale comment). Successive merges added spawn/analyzer-heavy suites — exactly the workload `dart_test.yaml`'s policy assigns to the `slow`/`e2e` tiers — but none were tagged. The lane crossed the 30-minute ceiling; `dart_core` now cancels on every run, so the pure-Dart gate is silently dark. Confidence: **high** (measured from the job log).

## Proposed Fix

1. Tag the identified heavyweight suites: process-spawning/temp-project suites → `e2e` (#1510 precedent: honest under direct invocation, excluded from the fast lane by the B4-pinned selector, runs in `--preset=all`); in-process slow suites (analyzer/compile gates, CI-proven ≥4s) → `slow`; add `slow` to the 8 tier-only regression files.
2. Add `--concurrency=4` to the `dart_core` test step — tagging alone cannot reach 8 min (serial residual ≈ 12–13 min across ~950 genuinely fast suites + kernel loads); the global `concurrency: 1` was a heavy-lane RAM/disk guard, and the residual unit lane is what upstream default parallelism is for (projects to ~3–5 min).
3. Pin it structurally: a fast-lane budget pin (tier_integrity precedent) failing when a fast-lane-eligible file matches the spawn/compile criteria without an exclusion tag; refresh the stale ci.yaml comment.

**Severity**: high — a mandatory-quality gate is cancelled on every run, silently skipping the pure-Dart suite for all PRs.

Assessment: `.specify/bugs/dart-core-lane-timeout-overflow/assessment.md`
