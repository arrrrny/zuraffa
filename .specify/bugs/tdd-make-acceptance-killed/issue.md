# Bug Issue: [BUG] zfa tdd make subprocess killed (exit -9) for acceptance behaviors

- **Slug**: tdd-make-acceptance-killed
- **Fetched**: 2026-09-02
- **Issue**: 796
- **URL**: https://github.com/arrrrny/zuraffa/issues/796
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

`zfa tdd make` for acceptance behaviors (A1-A9) fails with `generation-error` because the underlying `zfa make <id> --no-entity` subprocess gets killed (exit -9 = SIGKILL, likely OOM or timeout).

## Confirmation (v6.1.0 with fixes #744, #747, #748, #753)

Tested on a fresh project with the rebuilt zfa binary.

**Result:** BUG CONFIRMED.

```
[run] A1 gen -> ok
[run] A1 verify-red -> certified
[run] A1 make -> unexpressible
[run] A1 make -> deferred (phase 2)
[run] A2 gen -> ok
[run] A2 verify-red -> certified
[run] A2 make -> unexpressible
[run] A2 make -> deferred (phase 2)
[run] A3 gen -> ok
[run] A3 verify-red -> certified
[run] A3 make -> generation-error
zfa tdd run: step failed — behavior=A3 step=make outcome=generation-error
   zfa tdd make: behavior A3
   plan: 2 step(s)
   generation step failed at index 0 (generate use-case/repository scaffolds for a3 (behavior A3)):
   command: `/Users/ahmettok/.local/bin/zfa make a3 --no-entity`
   exit: -9
```

Note: spec 001 (app-bootstrap) completed all 21 behaviors. spec 004 (DI) fails at A3 make. The difference: spec 001 behaviors were all "unexpressible" (phase 2 deferred), so make was never actually run. spec 004 behaviors hit make and fail.

Direct test of the underlying command:
```
$ zfa make a3 --no-entity
❌ No active plugins to run.
```
The command completes with an error message but the TDD loop treats it as a crash (exit -9).

## Steps to Reproduce

1. `zfa setup --platforms=macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy any spec with acceptance behaviors (e.g. specs/004-dependency-injection/spec.md)
4. `zfa tdd plan 004-dependency-injection`
5. `zfa tdd run 004-dependency-injection`
   → **exit 1**: stops at A3:make with generation-error

## Workaround

Manually edit subjects to not throw UnimplementedError, or mark behaviors as green in run-state.json.

## Environment

- zfa version: v6.1.0 (with fixes #744, #747, #748, #753)
- Flutter version: 3.41.0+
- Dart version: 3.11.0+
- Platform: macOS

## Comments

None.