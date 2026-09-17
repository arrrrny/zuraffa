# TDD Verification — Spec 1653 — Verdict: PASS (feature scope, 2026-09-16)

Certification that `mutation_test` is opt-in at init, that init pays the
cold resolution at init time, and that the refactor receipt carries
per-phase durations — proven by the REAL runs listed below (never a stale
copy; every number in this file was produced by a command executed on this
branch, Dart SDK 3.13.4 stable, Linux x64).

## Runs executed (this branch)

| # | Command (repo root) | Result |
|---|---------------------|--------|
| R1 | `dart test --preset=all test/plugins/tdd/bug_1653_init_opt_in_and_preresolve_test.dart` | **PASS — +16: All tests passed!** (16/16: patcher default excludes `mutation_test` in both flavors; `includeMutationTest: true` injects `^1.8.0`; static maps keep the #755 pins; dry-run filters identically; default `TddBaselineInit` writes no `mutation_test`; `mutation: true` threads the opt-in; pre-resolve FIRES on newly-added deps with `dart pub get --no-example` + duration printed, SKIPS on idempotent pass, MISFIRES on non-zero resolver exit, WARNS on missing binary; unavailable-semantics hardening; `zfa tdd init --help` registers `--mutation`; CLI default init leaves `mutation_test` out; CLI `--mutation` adds `^1.8.0`) |
| R2 | `dart test --preset=all test/plugins/tdd/bug_1653_refactor_phase_timings_test.dart` | **PASS — +5: All tests passed!** (per-pass duration ≥ the programmed delay, null for a scheduling-skipped pass; `- phases:` + `duration:` render additively; legacy entry renders no timing lines and its chain hash is byte-identical with/without durations (schema v1 preserved); E2E green refactor (real `dart test` children in a TddFixture) prints `phase timings: preflight=6.8s registry=0.3s re-proof=…` and the cycle-log receipt carries `- phases:`; the FR-009 summary line format is byte-unchanged) |
| R3 | `dart test --preset=all test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart test/cli/writers/tdd/bug_1349_init_flutter_app_deps_test.dart test/cli/writers/tdd/bug_1370_flutter_consumer_test_baseline_test.dart` | **PASS — +29: All tests passed!** (the #1370 B1 pin re-pinned honestly to the #1653 default: no `mutation_test` in the injected set; #1349 misfire contract intact) |
| R4 | `dart test --preset=all test/plugins/tdd/services/refactor_passes_test.dart test/plugins/tdd/models/refactor_action_test.dart test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart test/plugins/tdd/bug_1327_cycle_log_terminal_receipt_test.dart test/package_sdk/bug_1369_example_tdd_baseline_test.dart` | **PASS — +47: All tests passed!** (registry mechanics, action rendering, evidence-integrity chain, terminal receipt, shipped-baseline pin) |
| R5 | `dart test --preset=all test/commands/doctor_checks_test.dart test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart` | **PASS — +19: All tests passed!** (doctor evidence walk over cycle entries; re-proof retry/no-op evidence entries) |
| R6 | `dart test --preset=all test/plugins/tdd/bug_837_mutation_verify_pipeline_test.dart test/plugins/tdd/bug_846_coverage_gate_test.dart test/plugins/tdd/bug_924_verify_preflight_test.dart` | **PASS — +32: All tests passed!** (the verify lane's audit semantics are UNTOUCHED — hard constraint honored) |
| R7 | `dart test --preset=all test/plugins/tdd/refactor_command_test.dart` | **+13 -1.** The single failure (A12, fake-zfa build-call log empty) **reproduces on pristine master** (verified via a fresh master checkout: same test, same failure) — pre-existing, unrelated to this feature; flagged, not fixed (out of scope) |
| R8 | `dart test --preset=all test/plugins/tdd/tdd_command_smoke_test.dart` | **+7 -1.** The failure (`zfa tdd --help` corpus line lacks 'ledger') **reproduces on pristine master** — pre-existing, unrelated; flagged, not fixed. The init smoke test (`zfa tdd init on an empty directory is idempotent`) PASSES with the new pre-resolve doing a real `dart pub get` in the fixture |
| R9 | `dart format --output=none --set-exit-if-changed <12 changed files>` | **PASS — exit 0** after one formatting pass; `git diff` shows zero remaining formatting diffs |
| R10 | `dart analyze <8 changed lib files>` | **PASS — No issues found!** (repo baseline carries 106 pre-existing info-level lints elsewhere; none on the changed surface) |

## Mutation evidence (real runs)

Scoped `mutation_test` (v1.8.0) audits over the feature's NEW/changed
surfaces, configs committed for reproduction:

| Scope | Config | Result |
|-------|--------|--------|
| `lib/src/plugins/tdd/services/pub_pre_resolver.dart` (the NEW service, 7 mutants) | `mutation-test-1653-resolver.xml` | **7/7 killed — Quality Rating A, Success: true** (first run was 6/7 with 1 survivor: `unavailable => !ran && reason != null` under `&&`→`||`; a hardening test was added (R1) and the re-run killed it) |
| `lib/src/plugins/tdd/models/refactor_action.dart` (5 mutants) | `mutation-test-1653-action.xml` | **2/5 killed by the scoped suite; the 3 survivors are ALL in the pre-existing `isGreen` getter (line 58) — code this feature does not touch.** Every mutant of the NEW `duration` field is killed. The pre-existing gap is recorded, not silently accepted |
| `lib/src/plugins/tdd/models/cycle_entry.dart` new lines (12 hand-driven mutants) | `scripts` walk (real `dart test` per mutant) | **12/12 killed** — the minutes-guard, seconds-modulo, padLeft width, decimal precision, ms scale, kind gate, null gate, emptiness gate, join separator, action-duration gate, and both additive-line labels are each proven load-bearing |

**Not completed within budget (honest gap):** the full 8-file audit
(`mutation-test-1653.xml` — 988 mutants over patcher/baseline_init/
init_command/refactor_command/refactor_passes + the three above) was
started twice for real and does not fit the session budget (~100s/mutant
cold → ~2.5h+). The committed config reproduces it. The first attempt ALSO
surfaced a real tooling finding, recorded below.

## Tooling finding (pre-existing, out of scope, flagged)

`tools/run-tdd-tests.sh` (the repo's own mutation-audit test command) runs
`dart test … --exclude-tags "flutter || e2e"`. dart_test.yaml ALREADY
excludes `slow` at the top level, and a CLI `--exclude-tags` flag COMBINES
with it (`slow || flutter || e2e`) — so every `@Tags(['slow'])` covering
test file is silently skipped and the repo's committed mutation audits
scored against an empty test set for those files. Discovered empirically:
the `pubGetArgs = []` mutant survived the wrapper run (35 tests "passed")
while failing the same file standalone. This PR's scoped wrappers use
`--preset=all` instead. Fixing the repo-wide script is outside this issue's
hard constraint (init injection + timing only) — flagged for a follow-up.

## Success criteria — PROVED vs not

- **SC-1 (mutation_test not injected by default; opt-in flag): PROVED**
  (R1: 16/16, both flavors + CLI wiring + #1528 preflight default path).
- **SC-2 (init pays the cold resolution at init time; idempotent passes
  skip): PROVED** (R1: resolver fires on newly-added deps with the exact
  argv `['pub','get','--no-example']`, duration printed on the ✓ line;
  zero spawns on an idempotent pass).
- **SC-3 (refactor receipt per-phase + per-pass durations): PROVED** (R2:
  E2E receipt carries `- phases: preflight=… registry=… re-proof=…` and
  per-pass `duration:`; FR-009 summary line byte-unchanged).
- **SC-4 (fresh app's first refactor no longer pays the mutation_test cold
  cost): PROVED at the mechanism level** (default init injects no
  `mutation_test` — the deferred-warm root cause is removed; mutation
  evidence above) and **ARGUED at the E2E level**: the issue's 8m32s
  zcalc probe could not be re-run here (no Flutter SDK in this
  environment; the warm 26–44s figures come from the issue's own
  measurements). Not re-measured end-to-end — recorded honestly.
- **SC-5 (analyze/format clean; covering suites green): PROVED** (R3–R6,
  R9, R10; the only failures on the branch are the two flagged
  pre-existing master failures in R7/R8).

## Residual risks

- Projects that relied on init-injected `mutation_test` now see verify's
  existing NOT_ASSESSED + `dart pub add dev:mutation_test` fix line until
  they opt in (`zfa tdd init --mutation`). The degradation is pre-existing
  behavior, honest, and documented in `docs/zfa-tdd-guide.md`.
- `zfa setup` (the patcher's other caller) also stops injecting
  `mutation_test` — the same fresh-app cold-cost class, desirable per
  SC-4, called out in the PR body.
