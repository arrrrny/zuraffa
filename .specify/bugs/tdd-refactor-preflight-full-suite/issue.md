# Bug Issue: fix(tdd): #734/#743 partial fix — refactor preflight still calls runSuite (full dart test)

- **Slug**: tdd-refactor-preflight-full-suite
- **Fetched**: 2026-09-02
- **Issue**: 754
- **URL**: https://github.com/arrrrny/zuraffa/issues/754
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

Issue #734 (refactor preflight full-suite false negative) was reportedly fixed via #743 (commit `13172c00`), but the fix did NOT change `refactor_command.dart` line 181 — the preflight still calls `runner.runSuite()` which runs `dart test` for the whole project. When U* behaviors are still red, the full suite fails and `outcome=not-green` is reported, even though the current behavior's test passes.

## Reproduction

```bash
# State: 12 done, U8 green (test passes), 36 pending (U9+ not yet generated)
zfa tdd run 004-cloud-agent-task-dispatch
# [run] U8 make -> green
# [run] U8 refactor -> not-green
# zfa tdd refactor: preflight suite
#    command: dart test
#    preflight exit: 1
```

The make step correctly classified U8 as green (per #731, #737, #751 fixes). The refactor step's preflight then ran `dart test` for the whole project, which has 36+ red tests (un-stubbed U9+), so the preflight fails.

## Root cause

`#743` (commit `13172c00`) was claimed to fix this but the refactor command was not actually updated. Looking at `lib/src/plugins/tdd/commands/refactor_command.dart`:
- Line 181: `final preflight = await runner.runSuite(...)` — still calls full suite
- Line 85: explicit comment "there is INTENTIONALLY no --skip-preflight option"

The fix that landed for #734 was either in a different file (run driver?) or the per-behavior logic exists but isn't reached when the run driver is in the "make succeeded, now refactor" path.

## Expected

The refactor preflight should verify the CURRENT behavior's test passes, not the full suite. Either:
- Pass the test path to a per-behavior test runner instead of `runSuite`
- Use a `--preflight-scope=current-behavior` flag (default) that takes the per-behavior test path
- The run driver should skip the refactor step entirely if make already returned green, deferring refactor to phase 2b only when ALL behaviors are green

## Actual

Refactor preflight always runs `dart test` (full suite), fails when any test is red.

## Verification

- A run where U8 is green and 36 others are pending should let U8:refactor pass (or skip cleanly)
- Direct `zfa tdd refactor U8` should succeed when `dart test test/tdd/u8_test.dart` passes
- The full suite should only be required at the very end (phase 2b absolute green) per the run_command.dart comment

## Context

Discovered 2026-09-02 running `zfa tdd run` on forklift spec 004 with all 9 prior fixes merged. U8:make is green (per #657, #731, #737, #751, #752), but U8:refactor fails the full-suite preflight because 36 U* stubs are still UnimplementedError.

This is the 5th fix-incomplete in this session. Pattern: the fix gets merged but the code path that the run actually exercises is unchanged.

Following STOP-ON-ROADBLOCK from zuraffa/AGENTS.md.

## Comments

None.
