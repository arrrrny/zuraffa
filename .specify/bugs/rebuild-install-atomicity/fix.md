# Bug Fix: rebuild-install-atomicity

- **Fixed**: 2026-10-17
- **Branch**: fix/issue-1744
- **Issue**: #1744

## Change list

1. `scripts/rebuild.sh` — new `install_binary_atomically <src> <name>` helper:
   copies the built binary to a sibling `$dest.rebuild.$$` temp file, `chmod +x`
   it, proves it byte-identical to `<src>` with `cmp -s` (deleting the temp and
   exiting 1 on any mismatch), then `mv -f`s it into place. Both the `zfa` and
   `zuraffa_mcp_server` installs now go through it (the old bare `cp` onto the
   live path is gone).
2. `scripts/rebuild.sh` — new smoke check immediately after the `zfa` install:
   `perl -e 'alarm shift; exec @ARGV' "$ZFA_SMOKE_TIMEOUT" "$INSTALL_DIR/zfa"
   --version`, bounded at `ZFA_SMOKE_TIMEOUT` (default 30 s). Non-zero/timeout
   exits 1 with a "installed binary is broken" message. It runs **before** the
   `✅ Rebuild complete` banner, which can therefore no longer print while the
   installed CLI is broken.
3. `test/scripts/rebuild_script_install_test.dart` (NEW) — regression guard:
   (a) static contract — the script stages, byte-verifies with `cmp -s`, renames
   with `mv -f "$tmp" "$dest"`, keeps the smoke check before the banner, and no
   longer contains the old direct `cp …/zfa "$INSTALL_DIR/zfa"`;
   (b) functional — a fake `dart` builds a bundle whose `zfa` exits 1, and the
   script must exit non-zero **without** printing `Rebuild complete`.
4. `.specify/bugs/rebuild-install-atomicity/assessment.md` (NEW) — the
   assessment for issue #1744.

## Root cause

`rebuild.sh` installed the freshly compiled `zfa` with a bare `cp` onto the live
`$INSTALL_DIR/zfa` path and never verified the result. A copy that landed torn,
or that raced a process executing/writing the destination, produced an installed
binary that differed from the artifact it had just built (the report measured one
contiguous ~4 KB window) and then spun/SIGSEGV'd — while the script still printed
`✅ Rebuild complete` and merely *suggested* `zfa --version`.

## TDD evidence

- **red**: `dart test test/scripts/rebuild_script_install_test.dart -j 1` on the
  unfixed tree —
  `00:01 +0 -2: Some tests failed.` with
  `does not contain 'install_binary_atomically'` and
  `Expected: not <0>  Actual: <0>` (the old script exited 0 and printed
  `Rebuild complete` for a bundle whose `zfa` cannot run).
- **green**: same command after the fix — `00:02 +2: All tests passed!`

## Constraint compliance

- Smallest diff: two install call-sites + one helper + one smoke check + one
  test file (plus the bug record). No unrelated refactors, no version bumps, no
  generated files touched.
- The bytes installed are now provably the bytes built (`cmp -s`), and the
  rebuild can no longer report success while the installed CLI cannot run.
