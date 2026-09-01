# Bug Issue: zfa tdd make still fails on unit behaviors (U5+)

- **Slug**: tdd-make-fails-unit-behaviors
- **Fetched**: 2026-09-01T17:23:21Z
- **Issue**: 718
- **URL**: https://github.com/arrrrny/zuraffa/issues/718
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**:

## Body

## Bug Description

`zfa tdd make` for unit behaviors still fails. When the run loop reaches a unit behavior (U5, U6, etc.), it stops with `outcome=generation-error` because the make step tries to run `zfa make <behaviorId>` (lowercased), treating the behavior ID as an entity name.

## Confirmation (v6.1.0, fresh project)

Tested on a fresh project at zfa v6.1.0.

**Result:** BUG STILL PRESENT — now the #1 blocker for the run loop.

```
[run] U5 gen -> ok
[run] U5 verify-red -> certified
[run] U5 make -> generation-error
zfa tdd run: step failed — behavior=U5 step=make outcome=generation-error
   zfa tdd make: behavior U5
   plan: 2 step(s)
   target test exit: 1
zfa tdd make: target test still fails after generation (exit 1).
```

Behavior IDs (U5, U6, etc.) are NOT entity names. The run loop stops at the first unit behavior because `zfa tdd make` wrongly tries entity generation.

## Steps to Reproduce

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy spec, run `zfa tdd plan 001-app-bootstrap`
4. `zfa tdd run 001-app-bootstrap`
   → **exit 1**: stops at `U5:make -> generation-error`

## Workaround

Manually mark unit behaviors as green in `run-state.json` to skip them, or create entities matching behavior IDs (wrong fix — behavior IDs are not entity names).

## Environment

- zfa version: v6.1.0
- Flutter version: 3.41.0+
- Dart version: 3.11.0+
- Platform: macOS

## Comments

None.
