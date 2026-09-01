# Bug Assessment: fix(tdd): gen skips stub when binary changes — stale stub causes make regression

- **Slug**: tdd-gen-stale-stub-binary-changes
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/683
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd gen` skips regenerating a stub when the ownership check returns "reused/reused", even when the zfa binary has been rebuilt with a fix. This causes `zfa tdd make` to run the test against the stale stub, producing a regression.

## Symptom

After rebuilding the zfa binary with a fix, `zfa tdd run` resumes and `gen` returns "reused/reused" (skips regeneration), leaving the old stale stub in place. `make` then runs the test against the stale stub → regression. Manual `dart test` passes, confirming the stub is stale and the test is correct.

## Reproduction

1. `zfa tdd run` on spec 004 → U1:gen produces stub v1.
2. `bash scripts/rebuild.sh` → binary updated with a fix.
3. `zfa tdd run` resumes → U1:gen returns "reused/reused", skips regeneration.
4. U1:make → regression (old stub still in place).

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/gen_command.dart` — ownership check returns "reused/reused" and skips regeneration.
- `lib/src/plugins/tdd/services/ownership_contract.dart` (spec 044) — ties stub content to the generating binary.

## Root Cause Hypothesis

The ownership contract (044) ties stub content to the generating binary. The "reused/reused" signal tells `gen` not to overwrite — but there's no check for whether the generating binary has changed since the stub was last written. When a binary update changes what the stub should contain, the stale stub causes downstream steps to fail. Confidence: **high** — the reproduction is deterministic and the root cause is clear.

## Proposed Remediation

**Preferred (Option B — lenient):** When the stub exists and ownership is "reused/reused", compare the stub's content against what the current binary's `zfa tdd func <id>` would write. If different, regenerate with a note "binary updated, stub regenerated". If identical, skip silently.

**Minimum viable:** Log a warning when "reused/reused" and binary mtime > stub mtime: `"stub is from an older binary; regenerate with --force to update"`.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/gen_command.dart`

**Tests to add or update**:
- Stub mtime older than binary mtime + `zfa tdd gen` returns "reused/reused" → stub is regenerated (or warning logged).
- Test suite passes after `zfa tdd make` on resumed run.
- No spurious regeneration when binary hasn't changed.

## Risks & Considerations

- Option B requires invoking `zfa tdd func <id>` to compute expected content — ensure this is fast and side-effect-free.
- The binary mtime check (Option A) is simpler but may regenerate unnecessarily if the binary was rebuilt without relevant changes.

## Open Questions

- None blocking.