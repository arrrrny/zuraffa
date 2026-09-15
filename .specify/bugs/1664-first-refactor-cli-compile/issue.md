# Bug Issue: perf(tdd) — first refactor after master bump pays one-time ~85s dart compile exe of zfa CLI even when parent runs from current installed binary

- **Slug**: 1664-first-refactor-cli-compile
- **Fetched**: 2026-09-15T20:30:00-07:00
- **Issue**: 1664
- **URL**: https://github.com/arrrrny/zuraffa/issues/1664
- **State**: open
- **Severity**: unknown
- **Author**: arrrrrny
- **Labels**: bug, build, tdd

## Body

# perf(tdd): after every master bump the FIRST refactor pays a one-time ~85s `dart compile exe` of the zfa CLI itself — even when the parent runs from a current installed binary

## Measured (fresh calculator app, v6.3.0+ @ c5ed519f, quiet machine)

First refactor of the first `zfa tdd run` after a master bump / binary rebuild:

- refactor wall: **124.6s** (steady-state band after the cache warms: **0.4–0.6s**)
- attribution (5s process sampler): `~/.local/bin/zfa tdd refactor A1 …` spawns
  `dart compile exe /Users/arrrrny/Developer/zuraffa/bin/zfa.dart --output /Users/arrrrny/Developer/zuraffa/.dart_tool/zfa_cli_bin/zfa_exe.tmp`
  at +32s; `gen_snapshot` runs ~85–100s writing `$TMPDIR/2w2PAV/snapshot.aot`
- output lands in the **zuraffa checkout's** `.dart_tool/zfa_cli_bin/zfa_exe`
  (25.9 MB), shared across all subsequent apps/children
- the parent binary was NOT stale: `~/.local/bin/zfa.build_commit` ==
  checkout HEAD (`c5ed519f`)

## Why it matters

The cost is one-time per source version and now cached, so steady-state is
excellent — but it lands inside the first refactor of the first app measured
after every update, where it reads as a regression of the #1634 class
(issue #1655 / PR #1656 fixed the build_runner entrypoint compile; this is the
remaining sibling). Fresh-app first-refactor should be ~40s; it measured 124.6s.

## Suggested remedies (any one)

1. **Prefer the running binary**: if the parent process is itself a compiled
   exe (resolved-executable path ends in a compiled artifact) and
   `.build_commit` matches the checkout HEAD, exec the parent for children
   instead of compiling (this is what #1643 intended for the stale case —
   extend it to the current case).
2. **Warm at install**: `scripts/rebuild.sh` already AOT-compiles the CLI;
   pre-populate `<checkout>/.dart_tool/zfa_cli_bin/zfa_exe` (or point the
   child seam at `~/.local/bin/zfa` directly) so the first app run never pays.
3. **Key the cache on the installed binary**: if an installed `zfa` exists and
   its recorded source commit matches, reuse it as the child runner.

## Evidence

`/tmp/zfa-measure/procs.log` (epoch window 1789502165–1789502330),
`/tmp/zfa-measure/101-run.log` (app `~/Developer/calculator_x`, run label 101).

## Comments

None.
