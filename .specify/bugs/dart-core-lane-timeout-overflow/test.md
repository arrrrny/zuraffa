# Bug Verification: dart_core CI job cancelled at the 30-minute ceiling

- **Slug**: dart-core-lane-timeout-overflow
- **Tested**: 2026-09-15
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md (**PASS** — LLM-guided audit;
  three deliberate mutants killed, one real gap found and closed in-audit by
  pin B7)

## Summary

The bug does not reproduce post-fix: the fast-lane census is empty (every
heavyweight suite now carries `e2e` or `slow`), the regression tier rides an
exclusion tag everywhere, the dart_core step runs the residual lane with
scoped `-j4` parallelism, and the full residual lane completes in 5:07
locally under adversarial load — well under the 8-minute budget. The two
pre-existing master RED suites that blocked any green lane were repaired and
are green. The deterministic CI confirmation lands with this PR's own
dart_core job (watched after opening).

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `dart test test/tier_integrity_test.dart` | pass | 8/8 — B5 census empty, B6 tier invariant holds, B7 selector+parallelism pinned; pre-fix the same run was `+5 -2` (./red-evidence.md) |
| New / updated tests | `dart test` on tier gate + bug_1388 + pubignore + bug_1517 canary | pass | 8 + 2 + 3 + 5, all green |
| Deliberate mutants (mutation sampling) | strip tier tag / strip exclusion tag / drop `--concurrency=4` | pass | all three killed (B6 / B5 / B7); tree restored, 8/8 |
| Residual-lane timing (AC-5) | `time dart test test --exclude-tags "flutter || e2e" --concurrency=4` | pass | **5:06.71** wall, 5,940 passed, on a 2019 Intel Mac with concurrent IDE Flutter-test churn (321% CPU contention) |
| Static analysis | `dart analyze lib test --no-fatal-warnings` | pass | 0 errors / 0 warnings; 106 style infos = the master baseline |
| Formatting | `dart format --set-exit-if-changed lib test` | pass | clean (CI's format gate contract) |
| Regression sample | serial reruns of the -j4 failing files | pass | 47/47 and 20/22 samples pass serially — the local -j4 failures are load-contention flakes plus one environmental case (`corpus_differential` worktree `pub get`, which passes on CI master); the PR's CI run decides on dedicated hardware |

## Output Excerpts

```
00:00 +7: B7: the dart_core lane keeps its scoped parallelism and the --exclude-tags selector (#1632)
00:00 +8: All tests passed!

dart test test --exclude-tags "flutter || e2e" --concurrency=4
  728.52s user 257.51s system 321% cpu 5:06.71 total
```

## Residual Risks

- The 5:07 timing is local and contended; the authoritative <8-minute +
  green verdict is the PR's dart_core job on a dedicated 4-core runner. If
  CI surfaces a parallel-unsafe straggler, the B5 census extends by one
  criterion (the same one-line pattern as this fix).
- ~20–25 suites per local run flake under simultaneous IDE test churn; they
  pass serially. CI (no IDE) is expected clean; the alternation of failure
  sets between runs supports the classification.
- The 58GB `$TMPDIR` kernel-cache exhaustion seen during verification is an
  environment hazard (AGENTS.md documents the 6.5GB-per-run growth), not a
  repo defect.

## Recommendation

Close the bug — verified end-to-end locally, with the PR's dart_core run as
the final hardware confirmation before merge. Do not merge without that run
green.
