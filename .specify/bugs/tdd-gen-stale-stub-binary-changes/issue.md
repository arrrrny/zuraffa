# Bug Issue: fix(tdd): gen skips stub when binary changes — stale stub causes make regression

- **Slug**: tdd-gen-stale-stub-binary-changes
- **Fetched**: 2026-09-01
- **Issue**: 683
- **URL**: https://github.com/arrrrny/zuraffa/issues/683
- **State**: open
- **Severity**: unknown
- **Author**: arrrrrny (Ahmet TOK)
- **Labels**: bug

## Body

`zfa tdd gen` skips regenerating a stub when the ownership check returns "reused/reused", even when the zfa binary has been rebuilt with a fix. This causes `zfa tdd make` to run the test against the stale stub, producing a regression.

## Symptoms

1. User runs `zfa tdd run` on a feature — U1:gen produces stub v1, U1:verify-red certifies red.
2. User rebuilds the binary (`scripts/rebuild.sh`) — binary now has a fix that would change the stub content.
3. User runs `zfa tdd run` again — U1:gen returns "reused/reused" (skips regeneration).
4. U1:make runs the test against the old stale stub — test still fails → regression.
5. Manual `dart test test/tdd/u1_test.dart` passes (confirms stub IS stale, test IS correct).

## Reproduction

- Run 1: `zfa tdd run` on spec 004 (before binary rebuild) — U1 stub = `int subject_u1() => throw UnimplementedError(...)`
- Rebuild: `bash scripts/rebuild.sh` (binary updated with #657 fix)
- Run 2: `zfa tdd run` resumes U1 — gen returns "reused/reused", skips stub regeneration
- U1:make → regression (old stub still in place)
- Manual test: `dart test test/tdd/u1_test.dart` → PASS (stub is stale, test is correct)

## Root cause

The ownership contract (044) ties stub content to the generating binary. The "reused/reused" signal tells `gen` not to overwrite — but there's no check for whether the generating binary has changed since the stub was last written. When a binary update changes what the stub should contain, the stale stub causes downstream steps to fail.

## Proposed fix

**Option A (strict):** `gen` compares the binary's modification time against the stub's mtime. If the binary is newer, regenerate even with "reused/reused" ownership — the binary's intent supersedes the cached ownership.

**Option B (lenient):** When the stub exists and ownership is "reused/reused", compare the stub's content against what the current binary's `zfa tdd func <id>` would write. If different, regenerate with a note "binary updated, stub regenerated". If identical, skip silently.

**Minimum viable:** Log a warning when "reused/reused" and binary mtime > stub mtime: `"stub is from an older binary; regenerate with --force to update"`.

## Verification

- Stub mtime older than binary mtime + `zfa tdd gen` returns "reused/reused" → stub is regenerated (or warning logged).
- Test suite passes after `zfa tdd make` on resumed run.
- No spurious regeneration when binary hasn't changed.