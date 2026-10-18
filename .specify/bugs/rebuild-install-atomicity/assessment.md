# Bug Assessment: rebuild.sh installs an unverified, non-atomic binary

- **Slug**: rebuild-install-atomicity
- **Created**: 2026-10-17
- **Source**: https://github.com/arrrrny/zuraffa/issues/1744 (pasted from the seed task)
- **Verdict**: valid
- **Severity**: high

## Report (condensed)

`./scripts/rebuild.sh` printed `✅ Rebuild complete` and its own suggested
verification step, `zfa --version`, then spun at ~43 % CPU for 8+ minutes
(five times) and died with
`si_signo=Segmentation fault: 11(11), si_code=SEGV_MAPERR(1), si_addr=0x228`.

The artifact the script itself built works:
`build/zfa_bundle/bundle/bin/zfa --version` → `zfa v7.1.0`, exit 0 (4.0 s).
Re-copying that artifact over `~/.local/bin/zfa` via temp + `mv` fixes it.

The installed file was byte-different from its own source artifact — same size,
same code directory, but one contiguous ~4 KB window differed
(`differing bytes: 3524`, `first 3280896`, `last 3284991`). So `rebuild.sh`
installs a binary that is not the bundle it just built, never notices, and
reports success.

## Symptom

Observed: `rebuild.sh` declares success while the binary it installed does not
work (`zfa --version` hangs then SEGVs). Expected: the script installs a binary
byte-identical to the artifact it built and passes a smoke check, or fails
loudly.

## Reproduction

1. `./scripts/rebuild.sh` → prints `✅ Rebuild complete`.
2. `zfa --version` → never returns; eventually `SEGV_MAPERR`.
3. `cmp` of `~/.local/bin/zfa` against
   `build/zfa_bundle/bundle/bin/zfa` → same length, ~4 KB of differing bytes.

The byte-level corruption is a race (a loaded machine, a `zfa tdd gen` process
executing the installed path while the rebuild overwrote it), so it is not
deterministically reproducible from a quiet tree. The **defect itself** is
deterministic and reproducible: the install is a bare `cp` onto the live path,
the installed bytes are never compared with the artifact, the binary is never
smoke-tested, and `✅ Rebuild complete` is printed unconditionally. The new
regression test reproduces that deterministically by building a bundle whose
`zfa` cannot run — the old script copied it blind and reported success.

## Suspected Code Paths

- `scripts/rebuild.sh:49` (old) — `cp build/zfa_bundle/bundle/bin/zfa
  "$INSTALL_DIR/zfa"` installs straight onto the live path: an in-place `cp`
  can be observed half-written, and nothing checks the landed bytes.
- `scripts/rebuild.sh:50-51` (old) — `chmod` + unconditional
  `echo "  ✅ $INSTALL_DIR/zfa"`; no verification of the installed binary.
- `scripts/rebuild.sh:84` (old) — `echo "✅ Rebuild complete …"` runs with no
  smoke test; `zfa --version` is only *suggested* at the end.
- The same non-atomic `cp` shape existed for `zuraffa_mcp_server`
  (`scripts/rebuild.sh:79`, old).

## Root Cause Hypothesis

Confidence: high. `rebuild.sh` installs with a non-atomic `cp` onto the live
destination and never verifies the result, so any copy that lands torn, or is
racing a process that is executing (or writing) the destination, produces a
broken installed binary while the script still prints success and suggests the
very verification command that then hangs/SIGSEGVs. The script has no guard
between "compile succeeded" and "declare the whole rebuild complete".

## Proposed Remediation

**Preferred** (matches the issue's suggested fix):

1. Install atomically with verification: stage the copy in a sibling temp file
   in the install dir, compare it byte-for-byte with the built artifact
   (`cmp -s`), then `mv` it into place. Do this for both binaries through one
   shared helper.
2. Smoke-test the installed `zfa --version` under a bounded wall clock
   (`perl -e 'alarm shift; exec @ARGV'`, since stock macOS has no `timeout(1)`)
   and `exit 1` on failure — **before** the `✅ Rebuild complete` banner.
3. The issue's third suggestion (make the ~4 KB AOT region deterministic) is
   conditional and not confirmable from here; the atomic install + smoke check
   converts the silent corruption into a loud, immediate failure, which is the
   issue's stated expectation.

**Files likely to change**:
- `scripts/rebuild.sh`

**Tests to add or update**:
- `test/scripts/rebuild_script_install_test.dart` (NEW) — asserts the script
  stages + `cmp -s` + `mv`s the install and smoke-checks before the banner
  (static contract), and functionally asserts that a bundle whose `zfa` cannot
  run fails the rebuild instead of printing success (the issue's determinism).

## Risks & Considerations

- The smoke check adds up to `ZFA_SMOKE_TIMEOUT` (default 30 s) to a rebuild.
  Bounded and overridable; far cheaper than the 8-minute spin it catches.
- The bounded check depends on `perl`, which ships with macOS. If it ever goes
  missing the rebuild fails loudly rather than silently skipping verification —
  the intended direction.

## Open Questions

- Whether the ~4 KB divergence at offset 3,280,896 is deterministic across two
  builds of the same commit is unproven (needs an x86_64 macOS host to rebuild
  twice). Left as a follow-up if it recurs once the install is verified.
