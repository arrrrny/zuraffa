# Bug Verification: non-adopting graceful exit after a crash consumes the interrupt marker while the crash mutation survives

- **Slug**: 1669-graceful-exit-consumes-marker
- **Tested**: 2026-09-16
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md (TDD mode — verdict: verified)

## Summary

The wedge no longer reproduces: a non-adopting graceful exit (the
`not-certified-red` refusal was exercised as the automated equivalent of the
assessment's reproduction) now KEEPS the interrupt marker while the crash
mutation survives on disk, and the kept marker un-wedges the very next resume
(`adopted-interrupted`, exit 0, current-hash green evidence, marker
consumed). No regressions: the shipped spec-1398 contract (U1–U4) and
recovery suite (A1/A2/A3/U5/U6/U7, including the SIGKILL harness) pass
unchanged.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `dart test test/plugins/tdd/bug_1669_refusal_keeps_crash_marker_test.dart -j 1` (A1 = the wedge scenario) | pass | marker survives the refusal + `issue #1669` retention note; RED pre-fix (`Expected: not null / Actual: <null>`) |
| The kept marker un-wedges the resume | A4 in the same file | pass | wedge → refusal keeps marker → certified red restored → `adopted-interrupted`, exit 0, current-hash evidence, marker consumed |
| New / updated tests | same file, 4 tests (A1/A2/A3/A4) | pass | A2/A3 pin the consume contracts (drift-free; clean-begin) |
| Mutation sampling | M1 drop provenance clause; M3 drop placeholder carve-out | pass | M1 killed by A3, M3 killed by spec-1398 A3 |
| Regression suite (spec-1398) | unit contract + recovery e2e incl. SIGKILL harness | pass | `+4` and `+6: All tests passed!` |
| Lint / type-check | `dart analyze` on touched files (+ repo `lib/`) | pass | no new issues |
| Format | `dart format lib test` | pass | 2715 files, 0 changed |

## Output Excerpts

```
00:10 +0 -1: ... A1 ... [E]   (pre-fix: the wedge — marker consumed by the refusal)
01:44 +2 -2: ... A4 ... [E]   (pre-fix: un-wedge impossible — marker already gone)
00:03:48 +4: All tests passed!  (post-fix)
08:36 +6: All tests passed!     (spec-1398 recovery e2e, unchanged)
```

## Residual Risks

- The local full-repo fast tier could not be re-run to completion: the
  shared per-user TMPDIR was contended by a concurrent session on the
  sibling checkout (kernel-cache/lock crossfire poisons any long local
  lane regardless of this change). CI's pristine runner is the
  authoritative gate; the touched surface is one branch inside
  `_printSummary` plus docs.
- The local-only `-j 4` failures observed in `test/plugins/tdd` during
  investigation (bug_1412/bug_1625 fake-zfa spawn signatures) reproduced
  with the fix stashed — parallelism artifacts of the same
  process-global-CWD hazard, addressed repo-wide by the serial dart_core
  lane (PR #1682), not by this fix.

## Recommendation

Close the bug — verified end-to-end at the driver level with mutation
sampling; ship via PR from `fix/1669-graceful-exit-consumes-marker`
(commit f1d62168).
