# Bug Assessment: perf(tdd) — first refactor after master bump pays a one-time ~85s dart compile exe of the zfa CLI even when the parent runs from a current installed binary

- **Slug**: 1664-first-refactor-cli-compile
- **Created**: 2026-09-15 (this session)
- **Source**: https://github.com/arrrrny/zuraffa/issues/1664
- **Verdict**: valid — root cause located; fix scoped to the child binary resolution seam
- **Severity**: performance regression class (reads as a #1634-class regression on first refactor after every update)

## Report (verbatim or summarized)

First refactor of the first `zfa tdd run` after a master bump / binary rebuild
pays a one-time ~85s `dart compile exe` of the zfa CLI itself, even though the
parent process runs from a CURRENT installed binary:

- refactor wall: 124.6s (steady-state band after the cache warms: 0.4–0.6s)
- attribution (5s process sampler): `~/.local/bin/zfa tdd refactor A1 …` spawns
  `dart compile exe <checkout>/bin/zfa.dart --output <checkout>/.dart_tool/zfa_cli_bin/zfa_exe.tmp`
  at +32s; `gen_snapshot` runs ~85–100s writing the snapshot
- the output lands in the ZURAFFA CHECKOUT's `.dart_tool/zfa_cli_bin/zfa_exe`
  (25.9 MB), shared across all subsequent apps/children
- the parent binary was NOT stale: `~/.local/bin/zfa.build_commit` == checkout
  HEAD (`c5ed519f`)

Fresh-app first-refactor should be ~40s; it measured 124.6s. The cost is
one-time per source version (cached afterwards), but it lands inside the first
refactor of the first app measured after every update.

## Symptom

The refactor step of the first `zfa tdd run` after every master bump spends
~85–100s in `dart compile exe` of `<checkout>/bin/zfa.dart` (plus `gen_snapshot`)
even though the driving installed binary is provably current for that checkout.

## Reproduction

From the issue (macOS dev machine, quiet):

1. `scripts/rebuild.sh` at checkout HEAD (installs `~/.local/bin/zfa` AOT
   binary + `zfa.build_commit` marker; note the script starts with
   `rm -rf build .dart_tool` — it WIPES `<checkout>/.dart_tool`, so the
   compile cache `<checkout>/.dart_tool/zfa_cli_bin/zfa_exe` starts EMPTY).
2. Run `zfa tdd run <feature>` against a fresh calculator app with the
   installed binary.
3. The first refactor step spawns
   `dart compile exe <checkout>/bin/zfa.dart --output <checkout>/.dart_tool/zfa_cli_bin/zfa_exe.tmp`
   and pays ~85–100s of AOT compile inside the refactor's wall clock.
4. Every subsequent refactor is 0.4–0.6s (warm cache).

## Suspected Code Paths

- `lib/src/cli/zfa_executable.dart` — `ZfaExecutable.ensureCompiled` /
  `_compileCached`: the ONE choke point every child binary resolution compiles
  through. The observed compile argv matches `_compileCached` exactly
  (`dart compile exe <candidate> --output <cacheDir>/zfa_exe.tmp`; scripts/zfa
  uses the same shape). On a cache miss/stale verdict it compiles the
  candidate source with NO awareness that the RUNNING process may itself be a
  compiled install that is provably current for the candidate's source tree.
- `lib/src/plugins/tdd/services/refactor_passes.dart` — `zfaBuildCommand` /
  `_pinToDrivingVersion`: the build pass resolution inside the refactor step
  child; resolves the entrypoint through `StepRunner.resolveEntrypoint` and
  compiles any `.dart` resolution through `ensureCompiled`.
- `lib/src/plugins/tdd/services/step_runner.dart` — `resolveEntrypoint` tiers:
  tier 1 returns a `.dart` script when `Platform.script` names an EXISTING
  `bin/zfa.dart`/`bin/zuraffa.dart` (the shape an installed binary built by an
  SDK whose AOT runtime bakes the source script path into `Platform.script`
  produces on the reporter's machine); the #1636 running-binary tier 4 only
  fires when no earlier tier resolves. Tier-1 source resolutions are then AOT
  compiled by `ensureCompiled` — the ~85s cost.
- `lib/src/cli/binary_staleness.dart` — the `zfa.build_commit` marker written
  by `scripts/rebuild.sh` next to the installed binary; the existing
  provable-current machinery the fix reuses (do not duplicate the constant —
  import `zfaBuildCommitMarker`).

## Root Cause Hypothesis

`ZfaExecutable.ensureCompiled`'s cache-miss path is the choke point that pays
the compile, and it has no awareness of a current installed binary. When the
child seam resolves the checkout's canonical `bin/zfa.dart` while the parent
runs from an installed compiled binary whose `zfa.build_commit` equals the
checkout HEAD, the compile is pure waste: the parent binary IS the artifact
that compile would rebuild (same source commit). `scripts/rebuild.sh` wipes
`<checkout>/.dart_tool` on every install, guaranteeing the cache-miss verdict
on the first run after every master bump — which is why the cost recurs per
update. This is the remaining sibling of #1643/#1645 (running-binary tiers for
the StepRunner/PipelineRunner resolution chains): those tiers fix WHICH
candidate the chain picks when the driver is compiled, but the compile seam
itself still compiles a source candidate unconditionally.

## Proposed Remediation

Remedy 1 from the issue (extend #1643 to the current case), implemented at the
compile choke point so every resolution path is covered:

- In `ZfaExecutable`, add an injectable probe (`currentInstalledBinary`): when
  (a) the candidate is the canonical package entrypoint
  (`bin/zfa.dart`/`bin/zuraffa.dart` of its source root), (b) the RUNNING
  process is a compiled (non-VM) executable, (c) the running binary's
  `<install-dir>/zfa.build_commit` exists and equals the candidate source
  root's `git rev-parse HEAD`, return the running binary INSTEAD of compiling.
- Wire the probe into `_compileCached` AFTER the fresh-cache check and BEFORE
  the build lock, so steady state (warm cache hit) is byte-for-byte unchanged
  and only the would-compile path is intercepted.
- Every probe failure mode (VM driver, missing/empty marker, git failure,
  commit mismatch, non-canonical candidate) returns null and falls through to
  the existing compile path — fail-open to current behavior, never a wrong
  binary.
- The `.build_commit` equality guard prevents stale reuse (acceptance
  criterion 3): an old install against a bumped checkout fails the comparison
  and compiles as before.

Hard constraints honored: child binary resolution only — no refactor pass
logic, no build-relevance gate, no CLI entry point changes.

## Risks & Considerations

- Uncommitted-checkout-edits case: commit equality proves the SOURCE COMMIT,
  not the working tree. A stale-marker install reused while lib/ has
  uncommitted edits would run pre-edit code in children. Mitigated by the
  check ordering: a FRESH compile cache (mtime-based `_isStale`) always wins
  first; the installed reuse only fires on cache miss/stale, exactly the
  would-compile moment. This is the trade the issue prescribes
  (`.build_commit` comparison as the staleness guard).
- Differential worktrees (`DifferentialRefRunner` compiles a REF worktree's
  `bin/zfa.dart`): the worktree HEAD differs from the installed binary's
  marker commit in the interesting cases, so the guard falls through to the
  compile — unchanged behavior. When a worktree IS at the marker commit, the
  reuse is semantically identical (same source).
- Custom `--zfa-bin <path>.dart` fixtures (corpus/fake-bin tests): NOT the
  canonical entrypoint → excluded by the canonical check → compiled as today.

## Open Questions

- None blocking. The exact SDK-version/tier that lands the source candidate
  (Platform.script baking behavior differs across SDK generations) does not
  affect the fix: the guard sits at the compile choke point every path
  funnels through.
