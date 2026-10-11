# Chore Implementation: Launcher cache copy-if-fresh tier

- **Slug**: launcher-cache-copy-if-fresh
- **Implemented**: 2026-09-17
- **Assessment**: none was committed for this chore — tracked in issue #1687 (the dead `./assessment.md` link was dropped per the PR #1688 review)
- **Status**: applied

## Summary

Added a copy-if-fresh tier to `scripts/zfa` that copies a fresh system binary (`~/.local/bin/zfa` or `zfa` on PATH) into the repo-local cache before falling through to a full compile. Also added `ZFA_NO_REBUILD=1` support and a doc note in `scripts/rebuild.sh` explaining the two-artifact relationship.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `scripts/zfa` | modified | Added `copy_if_fresh()` function, copy-before-compile logic, `ZFA_NO_REBUILD=1` support, header doc note |
| `scripts/rebuild.sh` | modified | Added doc note about dev-loop cache being separate |

## Diff Highlights

**copy_if_fresh() function** — checks `~/.local/bin/zfa` then `zfa` on PATH, verifies the binary is newer than all freshness inputs (same set as `needs_build`), then does `cp` + atomic `mv`:

```bash
copy_if_fresh() {
  local sys_bin=""
  if [ -f "$HOME/.local/bin/zfa" ]; then
    sys_bin="$HOME/.local/bin/zfa"
  elif command -v zfa >/dev/null 2>&1; then
    sys_bin="$(command -v zfa)"
  fi
  [ -z "$sys_bin" ] && return 1
  for f in "$ROOT/pubspec.yaml" "$ROOT/pubspec.lock"; do
    if [ -f "$f" ] && [ "$f" -nt "$sys_bin" ]; then return 1; fi
  done
  if [ -n "$(find "$ROOT/bin" "$ROOT/lib/src" -type f -newer "$sys_bin" -print -quit 2>/dev/null)" ]; then
    return 1
  fi
  mkdir -p "$CACHE_DIR"
  cp -f "$sys_bin" "$TMP" && mv -f "$TMP" "$EXE"
}
```

**Main build block** — tries copy-if-fresh first, then `ZFA_NO_REBUILD` guard, then falls through to compile as before:

```bash
if needs_build; then
  if copy_if_fresh; then :
  elif [ "${ZFA_NO_REBUILD:-}" = "1" ]; then
    echo "zfa: ZFA_NO_REBUILD=1 but no fresh system binary available ..." >&2
    exit 1
  else
    # existing compile path unchanged
  fi
fi
```

## Verification

- `bash -n scripts/zfa` → OK
- `bash -n scripts/rebuild.sh` → OK
- `dart test test/cli/zfa_executable_test.dart` → 19/19 passed
- `dart test test/cli/zfa_executable_1664_installed_binary_reuse_test.dart` → 10/10 passed
- Total: 29/29 tests passed

## Deviations from Assessment

None. The implementation follows the preferred approach exactly.

## Follow-ups

- Manual end-to-end test: `scripts/rebuild.sh`, delete `.dart_tool/zfa_cli_bin/zfa_exe`, run `scripts/zfa --version` — should complete in <2s (copy) instead of minutes (compile).

## Review-fix round (PR #1688 findings 1–5)

The first review of this PR reproduced four defects in the copy tier; the
launcher was hardened and the tier gained shell-level coverage:

- `copy_if_fresh` never reported a failed `cp`/`mv` (the final `echo` was the
  return value) — it now checks both steps, cleans the stage, and returns 1 so
  the caller falls through to the compile branch (`ZFA_NO_REBUILD=1` fails
  loudly, as documented).
- The copy staged through the shared `zfa_exe.tmp`, racing the compile path —
  it now stages under a per-process `zfa_exe.tmp.$$` name and renames
  atomically.
- Candidates are scanned in order (~/.local/bin/zfa, then PATH) and the first
  executable, fresh one wins — a stale local install no longer shadows a
  fresher PATH binary; non-executable sources are skipped and the staged copy
  is `chmod +x`ed.
- A present `zfa.build_commit` marker must equal the checkout HEAD before the
  candidate is adopted (the #1664 commit proof); a disagreeing or unresolvable
  marker falls through to compile.
- New `dart test test/cli/zfa_launcher_copy_if_fresh_test.dart` (9 tests, fast
  tier) pins copy-on-fresh, stale fall-through, `ZFA_NO_REBUILD=1`, the
  candidate scan, the marker proof, copy-failure reporting and concurrency
  (6/9 fail against the pre-fix launcher).
