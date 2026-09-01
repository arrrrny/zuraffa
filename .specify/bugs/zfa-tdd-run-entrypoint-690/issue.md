# Bug Issue: zfa tdd run: cannot resolve zfa entrypoint, requires --zfa-bin

- **Slug**: zfa-tdd-run-entrypoint-690
- **Fetched**: 2026-09-01
- **Issue**: 690
- **URL**: https://github.com/arrrrny/zuraffa/issues/690
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

`zfa tdd run <feature>` fails immediately with:
`cannot resolve the zfa entrypoint (package:zuraffa is not on the package path); pass --zfa-bin explicitly`

The command should auto-detect the system-installed `zfa` binary or default to a working path.

## Steps to Reproduce

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy any spec
4. `zfa tdd plan 001-app-bootstrap`
5. `zfa tdd run 001-app-bootstrap`
   → **exit 2**: cannot resolve the zfa entrypoint

## Expected Behavior

`zfa tdd run` should work out of the box after `zfa setup`.

## Actual Behavior

Fails because it tries to resolve `package:zuraffa` which is not on the package path. The workaround is `--zfa-bin /Users/ahmettok/.local/bin/zfa`.

## Workaround

`zfa tdd run 001-app-bootstrap --zfa-bin /Users/ahmettok/.local/bin/zfa`

## Environment

- zfa version: current
- Flutter version: 3.41.0+
- Dart version: 3.11.0+
- Platform: macOS

## Comments

None.
