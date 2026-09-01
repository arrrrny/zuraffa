# Bug Issue: zfa tdd init --force is silently ignored; should overwrite existing files

- **Slug**: tdd-init-force-silently-ignored
- **Fetched**: 2026-09-01
- **Issue**: 666
- **URL**: https://github.com/arrrrny/zuraffa/issues/666
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

Running `zfa tdd init` in a project that already has a `.specify/memory/tdd-profile.md` with different content (e.g., a project that was re-classified as Flutter vs. Dart, or a hand-edited profile) throws a `StateError` and exits non-zero — even when `--force` is passed.

The `--force` flag is **silently ignored**: it is accepted by the argument parser as an unknown extra and discarded, so `TddProfileWriter.write()` always hits its "refusing to overwrite" guard and throws.

**Expected**: `zfa tdd init --force` should overwrite the existing file and report success.

**Actual**:
```
$ zfa tdd init
zfa tdd init: ensuring TDD baseline in /Users/ahmettok/Developer/zuraffa_permissions (Dart)
   ✗ .specify/memory/tdd-profile.md: Bad state: tdd-profile.md already exists at
/Users/ahmettok/Developer/zuraffa_permissions/.specify/memory/tdd-profile.md with
different content; refusing to overwrite. Delete the file first if you want to regenerate.
```

## Root Cause

`InitCommand` never registers the `--force` flag, so it is silently absorbed as an unknown argument. `TddProfileWriter.write()` has no `force` parameter — it always throws `StateError` when an existing file's content differs from what it would generate.

## Proposed Fix

1. Register `--force` (`-f`) in `InitCommand.argParser`.
2. Pass a `force: bool` flag down through `TddProfileWriter.write()` (and the other baseline writers).
3. When `force == true` and the file exists with different content, delete and re-create it instead of throwing.

**Severity**: low (UX friction; work-around is to manually delete the file)