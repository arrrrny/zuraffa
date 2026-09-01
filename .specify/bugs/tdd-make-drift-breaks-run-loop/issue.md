# Bug Issue: [BUG] zfa tdd make: drift on already-green test breaks run loop

- **Slug**: tdd-make-drift-breaks-run-loop
- **Fetched**: 2026-09-01
- **Issue**: 694
- **URL**: https://github.com/arrrrny/zuraffa/issues/694
- **State**: open
- **Severity**: unknown
- **Author**: arrrrrny (Ahmet TOK)
- **Labels**: bug

## Body

`zfa tdd make` reports `outcome=drift` when the target test is already passing from a prior run. This breaks the `zfa tdd run` loop because the run-state thinks the behavior is `red` but the test is actually green.

## Steps to Reproduce

1. `zfa setup`, `zfa tdd init`, copy spec, `zfa tdd plan`
2. `zfa tdd run 001-app-bootstrap --zfa-bin ~/.local/bin/zfa` (runs A1-A9, some get made green)
3. Re-run `zfa tdd run 001-app-bootstrap --zfa-bin ~/.local/bin/zfa` → exit 1: `behavior=A9 step=make outcome=drift`

## Expected Behavior

`zfa tdd make` should detect already-green tests and either skip them or update the run-state to `green`.

## Workaround

Reset the subject stub to `throw UnimplementedError` before re-running, or delete `run-state.json`.