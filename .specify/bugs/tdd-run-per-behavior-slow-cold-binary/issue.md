# Bug Issue: fix(tdd): per-behavior U* tests are slow on cold binary — 5min per gen/verify-red/make cycle for unit plain-function behaviors

- **Slug**: tdd-run-per-behavior-slow-cold-binary
- **Fetched**: 2026-09-02
- **Issue**: 741
- **URL**: https://github.com/arrrrny/zuraffa/issues/741
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

## Summary

Running `zfa tdd run` on forklift spec 004 (49 behaviors) with all current fixes merged: each unit behavior takes ~5 minutes for the gen → verify-red → make cycle on a cold binary. With 39 U* behaviors still to process, the full run would take 3+ hours of pure wait time.

## Reproduction

```bash
# Per-behavior timing on the post-#720 binary:
# U1: 5:30 (gen ~3s + verify-red ~2s + make ~5min with suite baseline)
# U2: 4:50
# U3: 4:35
# U4: 5:10
# U5: 5:25
# Average: ~5 min per U behavior
```

## Root cause

The make step's suite baseline (`dart test` of the whole project) takes 1-3 min on this codebase (49 behaviors × stub compilation = large test tree). The verify-red step also runs the full suite to find the one test by name. Each step is sequential, not parallel.

## Expected

- Per-behavior test execution should be sub-30s
- The full `dart test` should not be needed to verify-red a single test by name — `dart test <file> --plain-name <name>` is sufficient (already supported)
- The suite baseline should be cached or skipped for behaviors whose own test passes

## Actual

- Each U behavior takes ~5 min, mostly in `dart test` (full suite)
- The cycle is dominated by 39 sequential suite runs

## Verification

- A spec with 44 unit behaviors should complete in <30 min on the same machine (currently ~3+ hours)
- `dart test <file> --plain-name <name>` should be the default for verify-red, not the full suite

## Context

Discovered while cataloging misfires on forklift spec 004. 8 distinct misfire types reported so far; this is the 9th. The 30+ remaining U* behaviors will all hit the same #737/#734 cycle. Performance issue is orthogonal to correctness but blocks the run from completing in a reasonable time.

Following STOP-ON-ROADBLOCK from zuraffa/AGENTS.md.

## Comments

None.