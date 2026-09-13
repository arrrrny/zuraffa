# TDD Verification — Spec 1601

**Audited**: 2026-09-13 (cold-context audit, LLM-guided — repo not zfa-wired)
**Verdict: PASS**

## Phase 1 — Test-first evidence

Source: `tdd/cycle-log.md` (reds recorded before their fixes).

| Behavior | Red evidence | Green evidence |
| -- | -- | -- |
| B1–B8, B10, B11 | batch missing-API red: loading failure — `plugin_scaffold.dart` / `plugin_family_names.dart` did not exist (`00:00 +0 -1`, recorded before any implementation) | C1 `00:03 +15: All tests passed!` (commit 3472ad8d) |
| B9 | compile red: missing `dart:convert` import in the e2e harness (fixed without touching assertions) | C2 `05:05 +1: All tests passed!` — real CLI scaffold, per-package pub get/analyze/test green in 3m51s (commit 2d87c21f) |

Reconciliation note (recorded honestly, not silent): mid-loop, a parallel
workstream's `stash` commit (9555fc80, issue #1604 / spec 1444 lineage)
landed a complete implementation on the branch. The spec-1601 behaviors
became the verification suite over it; the loop closed the real gaps as
TDD deltas (repository option FR-012, framework-path overrides placement
FR-006/FR-013, `plugin` alias FR-001, public csv parser FR-005, role
description stamping FR-012). Spec Assumptions were updated to the
delivered reality (initial version 0.1.0; `zuraffa_`-prefix-stripped class
nouns) with the change logged in the cycle log.

## Phase 2 — Test-smell rubric

- Assertions carry `reason:` strings naming the contract — no bare expects.
- No sleeps or time-based waits; subprocess budgets bounded
  (`_runSupervised` timeouts, suite `Timeout(8 min)` under a 5m05s wall).
- Fixtures are per-test temp dirs (`Directory.systemTemp.createTemp`),
  deleted in `tearDown`; the dry-run/real comparison cleans both dirs in
  `finally`; no test-to-test coupling.
- The B6 harness drives the GENERATED publish script for real (temp
  git repo, identity configured locally, `--no-verify`) rather than
  grepping it as text — the script's version alignment, constraint
  rewrite, changelog propagation, and commit are all proven by execution.
- CI-safety: the fast tier (15 cases) is offline pure Dart; the network
  tier (B9) is `integration, slow`-tagged and only runs under the
  integration preset.
- No test doubles the SUT: B9 runs the REAL CLI (AOT when available) via
  the repo's `run_zfa_source` helper.

No material smells.

## Phase 3 — Mutation sampling (rubric fallback; no CI mutation gate)

| Mutant | Change | Killed by | Result |
| -- | -- | -- | -- |
| M1 | adapter pubspec loses the `@@PKG@@_platform` dependency | B2 (`+0 -1` with mutant) | **killed** |
| M2 | adapter package stops emitting LICENSE | B4 (`+1 -1` with mutant; B4b survivor is the default-slug test, not the license check) | **killed** |
| M3 | `PluginFamilyNames.packageNames` publishes core last | B6 publish-order assertion (`+0 -1` with mutant) | **killed** |

Restoration after each mutant verified (`cmp` against backup for the
engine; `git checkout HEAD --` for the names file) and sealed by a full
green re-run: `00:21 +58: All tests passed!` (43 baseline + 15 feature).
**0 survived, 0 timed out.**

## Phase 4 — Acceptance-criteria coverage

| Requirement | Behavior(s) |
| -- | -- |
| FR-001 command + family scaffold | B1, B9 (real CLI, `plugin` alias) |
| FR-002 analyze/test clean untouched | B9 |
| FR-003 publish metadata + LICENSE/CHANGELOG | B4 |
| FR-004 dependency-graph wiring | B2 |
| FR-005 platform selection + rejection | B7, B8 |
| FR-006 dev-only overrides placement | B5, B5b |
| FR-007 publish tooling | B6 (executed) |
| FR-008 harness integrity | B3 |
| FR-009 dry-run purity | B11 |
| FR-010 validation rails | B10, B8 |
| FR-011 root docs + scripts | B1 |
| FR-012 description + repository stamping | B4 (`--repo`, explicit description) |
| FR-013 framework path override | B5b |
| SC-1 | B1, B9 |
| SC-2 | B4, B6; live `dart pub publish --dry-run` runs at delivery (T015) |
| SC-3 structural parity with zuraffa_auth | B1/B2 assert the same five-role shape, name derivation, dependency direction, and publish pipeline surface |
| SC-4 | delivery task T015 (zuraffa_ffi scaffolded, verified, pushed) |

## Gate verdict

**PASS** — no remediation tasks appended. Remaining work is the delivery
task T015 (issue #678's concrete deliverable), tracked in `tasks.md`.
