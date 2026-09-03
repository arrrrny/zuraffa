# Bug Issue: Differential harness: fixture parity between mock and real adapters

- **Slug**: differential-harness
- **Fetched**: 2026-09-03
- **Issue**: 915
- **URL**: https://github.com/arrrrny/zuraffa/issues/915
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

"Part of #908.

## Required

1. Fixture contract: one committed fixture set per adapter contract, consumed by BOTH the mock (source of responses) and the realize differential (expected outputs from real).
2. Schema-parity checker: mock fixture shape must equal real response shape (Zorphy types); drift = named verdict.
3. Fault-injection parity: the failure scenarios the mock rehearses (timeouts, 5xx, corrupted payloads) must be triggerable against real adapters in the integration lane.
4. Rollup: per-adapter parity score surfaced in corpus reports.

Builds on the landed simulate adapters (fix 832, commit 2334d1b6) — this issue turns them into the realization measuring stick."

## Comments

None.
