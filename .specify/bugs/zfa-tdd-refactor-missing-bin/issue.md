# Bug Issue: [BUG] zfa tdd refactor: calls dart run bin/zfa.dart build which does not exist

- **Slug**: zfa-tdd-refactor-missing-bin
- **Fetched**: 2026-09-01
- **Issue**: 689
- **URL**: https://github.com/arrrrny/zuraffa/issues/689
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

`zfa tdd refactor` hardcodes the path `dart run bin/zfa.dart build` as the build pass, but this file does not exist in a project bootstrapped by `zfa setup`.

`zfa setup` creates the system-level `zfa` CLI (at `~/.local/bin/zfa`), but does NOT create a `bin/zfa.dart` in the project. Therefore the refactor step always fails with exit 255.

## Steps to Reproduce

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy any spec (e.g. `specs/001-app-bootstrap/spec.md`)
4. `zfa tdd plan 001-app-bootstrap`
5. `zfa tdd gen A7 --feature=001-app-bootstrap`
6. `zfa tdd make --feature=001-app-bootstrap A7`
7. `zfa tdd refactor --feature=001-app-bootstrap A7`
   → **exit 255**: `dart: Could not resolve the package: Missing bin/zfa.dart in the package.`

## Expected Behavior

The refactor step should use the system-installed `zfa build` command, or create the `bin/zfa.dart` stub during setup/init.

## Actual Behavior

`dart run bin/zfa.dart build` fails because `bin/zfa.dart` does not exist.

`ls` of project after `zfa setup`:

System `zfa` is at: `~/.local/bin/zfa`

## Workaround

Manually create `bin/zfa.dart` as a passthrough to the system `zfa` binary, or use `zfa build` directly.

## Environment

- zfa version: current
- Flutter version: 3.41.0+
- Dart version: 3.11.0+
- Platform: macOS

## Comments

None.
