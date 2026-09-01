# Bug Issue: zfa tdd verify-red should not require --project (should default to CWD)

- **Slug**: tdd-verify-red-project-default-679
- **Fetched**: 2026-09-01T00:00:00Z
- **Issue**: 679
- **URL**: https://github.com/arrrrny/zuraffa/issues/679
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

When running `zfa tdd verify-red` (and other TDD sub-commands), the user must currently pass `--project` explicitly:

```
zfa tdd verify-red U1 --feature 001-permission-port --project .
```

The code already defaults to `Directory.current.path` when `--project` is absent, but the user still felt `--project .` was necessary — suggesting either the default is not working in some scenarios, or the UX is unclear about when it is needed.

## Expected Behavior

`zfa tdd verify-red` (and other `zfa tdd` sub-commands) should work from within the project directory **without** requiring `--project`:
```
zfa tdd verify-red U1 --feature 001-permission-port
```

This matches the behavior of other `zfa` commands that auto-detect the project root.

## Current Behavior

The `--project` flag defaults to `Directory.current.path` in all TDD commands (confirmed across `verify-red`, `make`, `run`, `gen`, `refactor`, `verify`, `func`, `wire`, `compose`, `plan`, `init`, and all `corpus_*` commands).

## Proposed Fix

Add auto-detection of the project root by walking up from CWD looking for `pubspec.yaml` (mirroring `zfa make`'s existing `_findProjectRoot()` helper). This makes the project root self-discoverable even when the command is run from a subdirectory, or when `Directory.current` points unexpectedly to a different location.

**Severity**: low (UX friction; workaround is `--project .`)
**Type**: enhancement / bug

## Comments

None.
