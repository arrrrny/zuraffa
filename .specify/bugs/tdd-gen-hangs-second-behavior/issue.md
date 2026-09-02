# Bug Issue: [BUG] zfa tdd gen hangs on second behavior (regression from #738)

- **Slug**: tdd-gen-hangs-second-behavior
- **Fetched**: 2026-09-02
- **Issue**: 744
- **URL**: https://github.com/arrrrny/zuraffa/issues/744
- **State**: open
- **Severity**: unknown
- **Author**: arrrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

After fix #738 (regression check compares only current behavior test), `zfa tdd gen A2` hangs indefinitely on a fresh project. The command does not complete and must be killed with SIGKILL.

## Confirmation (v6.1.0 with fixes #735, #738, #739)

Tested on a fresh project at zfa v6.1.0. A1 gen works, A2 gen hangs indefinitely (killed with SIGKILL after 20s). Regression introduced by fix #738.

## Steps to Reproduce

1. `zfa setup --platforms=macos`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy spec, `zfa tdd plan 001-app-bootstrap`
4. `zfa tdd gen A1 --feature 001-app-bootstrap` (works)
5. `zfa tdd gen A2 --feature=001-app-bootstrap` → hangs indefinitely

## Workaround

Kill the process and manually update run-state.json to skip A2.