# Bug Assessment: dart_core CI job cancelled at the 30-minute ceiling — the pure-Dart fast lane has overflowed

- **Slug**: dart-core-lane-timeout-overflow
- **Created**: 2026-09-15T11:00:21Z
- **Source**: pasted text (user report) + GitHub Actions run evidence (`arrrrny/zuraffa` ci.yaml runs, Sept 13–15 2026)
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> "currently our PR CI task dart_core is being skipped because it overflows 30 minutes. we already have ways to prevent this — skip the long running tests by tagging them slow. Investigate recent CIs, identify slow tests and tag them, make sure dart_core test is below 8 minutes."

## Symptom

The `dart_core` CI job (`.github/workflows/ci.yaml`, pure-Dart lane `dart test test --exclude-tags "flutter || e2e"`, `timeout-minutes: 30`) is cancelled at exactly ~30m14s on every recent run, so the pure-Dart suite is silently skipped for the whole PR/merge gate. Expected: the lane completes and passes within its budget — per this assessment's goal, the test step should land below 8 minutes.

## Reproduction

1. Push any commit to `master` or a PR branch (evidence: run 34951330675, master, 2026-09-15T09:13Z).
2. Observe the `dart_core` job: started 09:13:20, cancelled 09:43:39 (~30m19s) — `##[error]The operation was canceled.` during the "Dart Test (pure Dart, no Flutter)" step.
3. Every recent run shows the same outcome: 12 of the last 15 ci.yaml runs have `dart_core: cancelled` at ~30:14; the runs where the lane did finish are `failure` runs that still took 28m49s–29m46s (e.g. 34936969400: 06:26:57 → 06:56:43).
4. All eight sibling jobs pass in ≤ 24 minutes — only `dart_core` overflows.

## Evidence (from the 2026-09-15 master run 34951330675 job log)

- The test step ran 09:14:01 → 09:43:34 (29.5 min) **and never finished**: 6,962 tests across 1,037 suites completed, then the runner was killed mid-`test/cli/writers/tdd/bug_1349_init_flutter_app_deps_test.dart`.
- **57 more fast-lane-eligible suites never ran at all** (test/cli/standard ×11, test/agent/** ×23, test/cli/writers/tdd tail, test/skew, test/migration, test/device, test/testing) — the true full-lane duration is strictly greater than 30 minutes.
- **No single monster test**: the largest gap between consecutive test completions is 32.1s. Top file is `test/commands/dead_positional_grammar_test.dart` at 80.1s (11 tests ≈ 7s each — it spawns the real CLI).
- Time is a long tail of heavyweight suites plus per-suite kernel compile (silent stretches ≥5s total 790s = 45% of the run):
  - `test/plugins/tdd/commands` — 383.5s
  - `test/commands` — 257.1s
  - `test/plugins/tdd` — 192.7s
  - `test/plugins/tdd/services` — 131.9s
  - `test/templates/self_hosting` — 102.4s (analyzer/compile self-hosting gates)
  - `test/skin` — 46.7s (VmTapDriver real-virtual-machine driver), `test/plugins/mock` — 43.0s
- 75 suites that ran directly spawn external processes (`Process.run/start`, `run_zfa_source`, `zfa_executable`, `dartTest` helpers) and account for 582s.
- The `slow` exclusion itself works: no `@Tags(['slow'])` file appears in the log — the lane is overfull with **never-tagged** heavy suites.
- The workflow comment "this job runs at ~22 of its 30 budgeted minutes" (ci.yaml:43) is stale.

## Suspected Code Paths

- `.github/workflows/ci.yaml:15-45` — the `dart_core` job; stale budget comment; serial execution (`concurrency: 1` inherited from `dart_test.yaml`).
- `dart_test.yaml` — tier/tag policy: `exclude_tags: slow` (default), `concurrency: 1` (introduced for heavy temp-project lanes that `pub get` + `build_runner` in /tmp, not for the pure-Dart unit lane).
- ~116 never-tagged heavyweight suites that ran in the cancelled lane (582s in direct spawn files alone; top offenders: `test/commands/dead_positional_grammar_test.dart` 80.1s, `test/plugins/tdd/commands/run_driver_timeout_receipt_test.dart` 63.4s, `test/commands/make_pubsync_zuraffa_ensure_test.dart` 48.5s, `test/plugins/tdd/commands/bug_1544_run_continue_after_blocked_test.dart` 48.2s, `test/skin/vm_tap_driver_test.dart` 41.4s, `test/commands/skin_drive_command_test.dart` 40.7s, `test/plugins/tdd/services/subprocess_timeout_test.dart` 40.6s …) plus 57 untagged suites cut off before running.
- 8 regression-tier files tagged `@Tags(['regression'])` **without** `slow` (e.g. `test/regression/issue_942_entity_name_collides_framework_export_test.dart`) — a small (~7s) leak that violates the documented invariant that tier suites are default-excluded via `slow`.

## Root Cause Hypothesis

The dart_core fast lane was scoped when the pure-Dart suite fit comfortably (~22 min per the now-stale ci.yaml comment). Successive merges added run-driver, corpus-economics, grammar-sweep, skin-driver, and self-hosting compile suites that spawn external processes or run analyzer/compile passes — exactly the workload `dart_test.yaml`'s own policy says belongs in the `slow`/`e2e` tiers — but none of them were tagged. The lane crossed the 30-minute job ceiling; GitHub now cancels `dart_core` on every run, so the pure-Dart gate is silently dark for all PRs. Confidence: **high** (directly measured from the job log).

## Proposed Remediation

**Preferred** (three coordinated changes, honoring the existing tier policy):

1. **Tag the identified heavyweight suites** so the default `slow` exclusion and the CI `--exclude-tags "flutter || e2e"` selector keep them off the fast lane:
   - Suites that spawn external processes (`dart`/`zfa` children, temp projects, run drivers) → `@Tags(['e2e'])` per the #1510 precedent — honest under direct `dart test <file>` invocation, excluded from the CI fast lane by the existing B4-pinned selector, still run in opt-in heavy lanes (`--preset=all`).
   - In-process-but-slow suites (analyzer/compile self-hosting gates, CI-proven ≥4s files without process spawns) → `@Tags(['slow'])`.
   - Add `slow` to the 8 tier-only `@Tags(['regression'])` files → `@Tags(['regression', 'slow'])`.
2. **Scope sane parallelism to the fast lane**: add `--concurrency=4` to the `dart_core` test step. Math: even after tagging every measured offender, the serial residual is ~12–13 min — tagging alone **cannot** reach 8 minutes because the remaining time is a thin tail across ~950 genuinely fast suites plus per-suite kernel loads. The global `concurrency: 1` exists to protect heavy temp-project lanes from RAM/disk exhaustion; the residual pure-Dart unit lane is exactly what upstream's default parallelism is for. At 4-way the residual projects to ~3–5 min.
3. **Pin the fix structurally** (tier_integrity_test.dart precedent): a fast-lane budget pin that fails when a fast-lane-eligible file matches the spawn/compile criteria (or accumulates proven CI time) without carrying an exclusion tag — so the drift that caused this bug cannot silently recur. Also refresh the stale ci.yaml comment.

**Alternatives**:
- Raise `timeout-minutes` on `dart_core` (e.g. 45) — rejected: leaves the PR gate at ~35+ min wall time and contradicts the stated goal; the lane would keep drifting.
- Shard `dart_core` into multiple matrix jobs — more robust long-term but larger CI surgery than needed once the heavy suites are re-homed; can be a follow-up.

**Files likely to change**:
- ~170 test files (annotation-only: `@Tags(...)` headers) — heavy suites under `test/plugins/tdd/**`, `test/commands/**`, `test/templates/self_hosting/**`, `test/skin/**`, `test/cli/**`, `test/agent/**`, `test/regression/*` (8 files), plus scattered ≥4s offenders.
- `.github/workflows/ci.yaml` — `--concurrency=4` on the dart_core test step + comment refresh.
- `dart_test.yaml` — comment update documenting the fast-lane budget policy (no selector change; B3/B4 pins unaffected).
- new/extended pin test: `test/tier_integrity_test.dart` or `test/ci/fast_lane_budget_test.dart`.

**Tests to add or update**:
- Fast-lane budget pin: every fast-lane-eligible `*_test.dart` matching the spawn/compile criteria must carry `slow` or `e2e` (prevents recurrence).
- Existing pins must stay green: `test/tier_integrity_test.dart` (B1–B4).

## Risks & Considerations

- Parallelism: some suites may assume serialization (the global cap has been in place a long time). Mitigation: local `-j4` verification run of the residual lane + the PR's own CI run.
- Coverage: tagged suites no longer run on every PR (they move to opt-in heavy lanes). This is the accepted tradeoff per the report and the existing tier policy.
- The 57 cut-off suites' runtime is unknown (never measured in CI); they are covered by the same tagging rule so they cannot re-float the lane.
- `@Tags` annotations require `package:test` imports — all `*_test.dart` files already import it; the pin test + `dart analyze lib test` will catch any miss.
- AGENTS.md formatting contract: run `dart pub get --no-example` before `dart format lib test`.

## Open Questions

- None blocking. (Follow-up candidate, out of scope here: sharding dart_core if the residual lane regrows past its budget.)
