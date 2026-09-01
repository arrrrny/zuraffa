# Bug Issue: [BUG] zfa tdd run: unexpected-green on already-completed behavior breaks the run loop

- **Slug**: tdd-run-unexpected-green-breaks-loop
- **Fetched**: 2026-09-01
- **Issue**: 691
- **URL**: https://github.com/arrrrny/zuraffa/issues/691
- **State**: open
- **Severity**: unknown
- **Author**: arrrrrny (Ahmet TOK)
- **Labels**: bug

## Body

`zfa tdd run` fails with `unexpected-green` when a behavior's test is already green from prior work (e.g., manual make). The run loop should detect already-green tests and skip them, or at least not treat it as a failure.

## Steps to Reproduce

1. `zfa setup`, `zfa tdd init`, copy spec, `zfa tdd plan`
2. Manually run `zfa tdd gen A7`, `verify-red A7`, `make A7` (test now green)
3. `zfa tdd run 001-app-bootstrap --zfa-bin ~/.local/bin/zfa` → exit 1: `behavior=A7 step=verify-red outcome=unexpected-green`

## Expected Behavior

The run loop should detect that A7 is already green and skip it (or mark it done), not fail.

## Workaround

Delete the green test/subject before running `zfa tdd run`.