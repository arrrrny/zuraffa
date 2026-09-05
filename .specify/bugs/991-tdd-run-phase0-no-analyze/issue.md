# Issue: `zfa tdd run` phase-0 build fails on any `dart analyze` warning — no `--no-analyze` forwarded

- **Slug**: 991-tdd-run-phase0-no-analyze
- **Severity**: medium
- **Component**: `zfa tdd run` driver — phase-0 entity orchestration (bug #829 follow-up)
- **Source**: runbook section-3 record (no pre-existing `.specify/bugs/991-*/` record found in the tree; this file was created by the fix session per the #942 provenance precedent)

## Symptom

`zfa tdd run 005-pr-status-reconciliation --timeout 5` reaches the phase-0
build step and the run stops with `runner-error` before any behavior is
driven.

## Reproduction

1. Target repo carries pre-existing `dart analyze` findings — 41 warnings
   (unused imports, dead code) but no compile errors; the code builds.
2. `zfa tdd run 005-pr-status-reconciliation --timeout 5`
3. Phase-0 creates the declared entities, then spawns a bare `zfa build`.
4. `zfa build`'s default `--analyze` post-build gate runs `dart analyze`;
   the build exits 1.
5. The driver reports `runner-error` / `stopped_at=phase-0:build` and the
   run stops. `build_runner` itself succeeded (everything skipped/compiled).

## Expected

The phase-0 build is a generation gate, not an analysis gate: it should not
fail on analyze findings that pre-date the run. Either the phase-0 build
uses `--no-analyze` (analyze belongs in the verify/refactor steps), or
`zfa tdd run` accepts a flag to forward. Current behavior breaks runs on
repos with pre-existing analyze warnings even when the code compiles.

## Hard constraints (from the runbook)

- Fix the phase-0 build to not fail on analyze warnings.
- Do NOT remove analyze from the verify/refactor steps.
- One PR for the bug.
