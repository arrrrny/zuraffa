# Bug Issue: [BUG] zfa tdd run: unexpected-green on already-completed behavior breaks the run loop

- **Slug**: zfa-tdd-run-unexpected-green
- **Fetched**: 2026-09-01
- **Issue**: 691
- **URL**: https://github.com/arrrrny/zuraffa/issues/691
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

`zfa tdd run` fails with `unexpected-green` when a behavior's test is already green from prior work (e.g., manual make). The run loop should detect already-green tests and skip them, or at least not treat it as a failure.

## Steps to Reproduce

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy spec, run `zfa tdd plan 001-app-bootstrap`
4. Manually run `zfa tdd gen A7`, `zfa tdd verify-red A7`, `zfa tdd make A7` (test now green)
5. `zfa tdd run 001-app-bootstrap --zfa-bin ~/.local/bin/zfa`
   → **exit 1**: `behavior=A7 step=verify-red outcome=unexpected-green`

## Expected Behavior

The run loop should detect that A7 is already green and skip it (or mark it done), not fail.

## Actual Behavior

`verify-red` on an already-green test reports `unexpected-green` and the entire run loop stops.

## Workaround

Delete the green test/subject before running `zfa tdd run`, or run `zfa tdd run` on a fresh feature where no behaviors have been manually completed.

## Environment

- zfa version: current
- Flutter version: 3.41.0+
- Dart version: 3.11.0+
- Platform: macOS

## Comments

None.
