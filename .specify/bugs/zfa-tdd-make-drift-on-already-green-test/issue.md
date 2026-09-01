# Bug Issue: [BUG] zfa tdd make: drift on already-green test breaks run loop

- **Slug**: zfa-tdd-make-drift-on-already-green-test
- **Fetched**: 2026-09-01
- **Issue**: 694
- **URL**: https://github.com/arrrrny/zuraffa/issues/694
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

## Bug Description

`zfa tdd make` reports `outcome=drift` when the target test is already passing from a prior run. This breaks the `zfa tdd run` loop because the run-state thinks the behavior is `red` but the test is actually green.

## Steps to Reproduce

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy spec, run `zfa tdd plan 001-app-bootstrap`
4. `zfa tdd run 001-app-bootstrap --zfa-bin ~/.local/bin/zfa` (runs A1-A9, some get made green)
5. Re-run `zfa tdd run 001-app-bootstrap --zfa-bin ~/.local/bin/zfa`
   → **exit 1**: `behavior=A9 step=make outcome=drift`

## Expected Behavior

`zfa tdd make` should detect already-green tests and either skip them or update the run-state to `green`.

## Actual Behavior

`zfa tdd make` exits with `outcome=drift` and the run loop stops.

## Workaround

Reset the subject stub to `throw UnimplementedError` before re-running, or delete `run-state.json` to force a fresh run.

## Environment

- zfa version: current
- Flutter version: 3.41.0+
- Dart version: 3.11.0+
- Platform: macOS

## Comments

None.
