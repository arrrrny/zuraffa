# Bug Verification: tdd-doctor-feature-positional (#1585)

- **Slug**: tdd-doctor-feature-positional
- **Tested**: 2026-09-13
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md (verdict: PASS)

## Summary

The issue's reproduction (4 doctor tests failing on the `--feature` usage
error) no longer reproduces: the helper uses the command's declared positional
form and the suite is 14/14. Fixing it surfaced two defects the usage error had
masked — the doctor's dropped evidence hash-chain walk and the retired
`drifts=<n>` summary assertion — both fixed with pins; the walk's two arms are
killed-mutant-verified. No regression is attributable to the change: the 11
sibling-suite failures in the sweep are identical on pristine `origin/master`.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (pre-fix) | `dart test --preset=all test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart` | reproduced | `02:38 +9 -4`, the issue's usage text captured verbatim |
| Reproduction (post-fix) | same | pass | `04:57 +14: All tests passed!` |
| New / updated tests | `--plain-name "hash chain"` / `"broken prev-hash LINKAGE"` | pass | both pins green; each kills its mutant (M1 / M2) |
| Mutation sampling | M1 (walk disabled), M2 (linkage arm dropped) | pass | both mutants killed, then reverted; tree re-ran green |
| Regression sweep (siblings) | `dart test --preset=all` on the 14 doctor-invoking suites | pass* | `+28 -11`; the same `+28 -11` on a pristine `origin/master` worktree → the 11 are pre-existing, none in the changed surface |
| Lint / type-check | `dart analyze <both changed files>` | pass | `No issues found!` |
| Format | `dart format <both changed files>` | pass | `0 changed` |

\* The sweep's exit code is 1 because of the pre-existing failures; the
verification-relevant fact is the identical base comparison.

## Output Excerpts

```
02:38 +9 -4: Some tests failed.
  ❌ Could not find an option named "--feature".
  Usage: zfa tdd doctor <feature> [--repair] [--project <path>]

04:57 +14: All tests passed!
```

```
M2 (linkage arm dropped):
  Expected: <1>
    Actual: <0>
  zfa tdd doctor: feature 090-bug-828 (specs/090-bug-828/tdd)
    stores agree — no drift detected
00:05 +0 -1: Some tests failed.
```

## Residual Risks

- The suite only runs under `--preset=all` (slow tag); a regression in it will
  not be caught by the default CI lane — unchanged by this fix.
- The 11 pre-existing sibling failures (gen/reset/run/migrate-paths assertions)
  remain red on master and are outside this bug's scope.
- No end-user surface beyond `zfa tdd doctor` is affected; the walk is
  read-only and fail-open for legacy (hash-less) logs.

## Recommendation

Close the bug — verified end-to-end: the reported symptom is gone, the two
defects it masked are fixed and mutation-pinned, and no regression is
attributable to the change. Merge the fix branch (PR linked from `pr.md`).
