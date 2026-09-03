# 894-corpus-economics

- **Spec ID**: 894-corpus-economics
- **Created**: 2026-09-03
- **Source**: GitHub issue #916 (ROADMAP P2)
- **Type**: feature
- **Priority**: P2

## Problem

The 120-spec corpus full verify takes too long on current hardware. Measured on Intel Mac (4 features / 76 tests):
- `zfa build`: 1m08s
- Full suite: 2m21s
- ONE refactor (2 suite runs + build): 9m30s
- Default 10m step timeout sits on a knife edge (killed at 10m00s; identical run passed manually at 9m30s)

The 120-spec corpus full verify must complete ≤ 30 min on this hardware class; per-PR corpus lane ≤ 10 min via sharding.

## Goal

Optimize the corpus verification pipeline to make all-120 verify run in minutes, not tens of minutes. Engineer frequency of gates while keeping full gate intact.

## Required (system fix)

1. **Incremental verification**: refactor re-proof scoped to pass-registry-changed files; full-suite proof once per feature completion + nightly — full gate still exists, frequency engineered.
2. **Batched gen/verify-red**: `zfa tdd gen --all` lineage to cut per-behavior `dart test` spawns.
3. **Sharding + concurrency** for the corpus lane; budget telemetry (wall-clock per step, suite seconds, mutant count) in JSON verdicts.
4. **Baseline cache reuse** extended corpus-wide (builds on #741 machinery, live-verified).

## Acceptance

- 120-spec corpus full verify ≤ 30 min on Intel Mac class hardware
- Per-PR corpus lane ≤ 10 min via sharding

## References

- #916 (GitHub issue, ROADMAP P2)
- #908 (Mock-First Realization parent)
- #741 (baseline cache machinery)
- #792, #785 (batching asks)
- #845 (live-measured evidence)

## Out of scope

- Changing the full verify gate (it still exists, just frequency engineered)
- Hardware upgrades (optimize on current hardware class)