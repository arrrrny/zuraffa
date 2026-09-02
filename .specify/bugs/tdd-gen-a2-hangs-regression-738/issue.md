# Bug Issue: [BUG] zfa tdd gen hangs on second behavior (regression from #738)

- **Slug**: tdd-gen-a2-hangs-regression-738
- **Fetched**: 2026-09-02
- **Issue**: 744
- **URL**: https://github.com/arrrrny/zuraffa/issues/744
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

## Bug Description (Regression)

After fix #738 (regression check compares only current behavior test), `zfa tdd gen A2` hangs indefinitely on a fresh project. The command does not complete and must be killed with SIGKILL.

## Confirmation (v6.1.0 with fixes #735, #738, #739)

Tested on a fresh project created with `zfa setup --platforms=macos` at zfa v6.1.0.

**Result:** BUG CONFIRMED — regression introduced by fix #738.

```
$ zfa tdd run 001-app-bootstrap
[run] A1 gen -> ok
[run] A1 verify-red -> certified
[run] A1 make -> unexpressible
[run] A1 make -> deferred (phase 2)
[run] A2 gen -> error
zfa tdd run: step failed — behavior=A2 step=gen outcome=error
```

Direct test:
```
$ zfa tdd gen A2 --feature 001-app-bootstrap
# hangs indefinitely (killed with SIGKILL after 20s)
```

The regression check added in fix #738 appears to hang when processing the second behavior (A2).

## Steps to Reproduce

1. `zfa setup --platforms=macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy spec, run `zfa tdd plan 001-app-bootstrap`
4. `zfa tdd gen A1 --feature 001-app-bootstrap` (works)
5. `zfa tdd gen A2 --feature=001-app-bootstrap`
   → **hangs indefinitely**

## Workaround

Kill the process and manually update run-state.json to skip A2.

## Environment

- zfa version: v6.1.0 (rebuilt with fixes #735, #738, #739)
- Flutter version: 3.41.0+
- Dart version: 3.11.0+
- Platform: macOS

## Comments

None.