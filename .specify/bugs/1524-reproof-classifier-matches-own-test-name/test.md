# Bug Test: the kernel-cache signature scan is immune to its own test-name progress line

- **Slug**: 1524-reproof-classifier-matches-own-test-name
- **Tested**: 2026-09-12
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified (red → green, real runs)
- **TDD artifacts**: `tdd/test-list.md` (the behavior list) and
  `tdd/verification.md` (fresh evidence from the actual runs), both in this
  directory.

## Test surface

`test/plugins/tdd/reproof_failure_classifier_test.dart` — new group
`classifyReproofFailure — poison test-name progress line (bug #1524)`,
5 tests over the pure classifier (no I/O, no subprocesses):

1. **`hasKernelCacheSignature ignores a reporter progress line`** — the
   poison line (the classifier's own group + test name in reporter progress
   grammar, quoting the #1333 signature) is not crash evidence. This is the
   issue's defect in isolation.
2. **`a genuine red re-proof with the poison line stays a regression`** —
   the issue's exact scenario: `exitCode: 1`, transcript = poison line +
   `00:01 +2918 -1: test/some_test.dart: a real regression [E]` +
   `Expected: 2 / Actual: 1` + `Some tests failed.` → must classify
   `regression`, never `infraRunner`.
3. **`kernelCacheSignatureLine finds no signature in a poisoned red`** —
   diagnostics stay consistent with the verdict: null, not the poison line.
4. **`the canonical crash line is still infra next to the poison line`** —
   the over-filtering guard: a canonical
   `Cannot retrieve length of file: …dart_test.kernel…dill (errno 2)` crash
   line (NOT a progress line) still classifies `infraRunner` when the
   poison line is also present (`exitCode: 255`). Proves the progress-line
   skip does not swallow genuine evidence.
5. **`bare phrase without crash evidence on the same line is not infra`** —
   the second fix component: a non-progress line quoting the bare phrase
   with no `.dill` / `dart_test.kernel` / errno / ENOENT evidence on the
   same line is not crash evidence.

The suite file is SELF-POISONING by construction: running it makes `dart
test` echo the real group + test names (including the existing #1333
signature-named test) as progress lines, so every green run of this very
file re-exercises the poison shape end to end.

## Red-green evidence (summary)

- RED (commit `ad4d6663`, tests only, classifier unfixed): 15 passed / 4
  failed — tests 1, 2, 3 and 5 failed for the RIGHT reason (test 2 printed
  `Expected: ReproofFailureClass:<ReproofFailureClass.regression> / Actual:
  ReproofFailureClass:<ReproofFailureClass.infraRunner>` — the issue's
  hijack itself; test 4 is the over-filtering guard and passed on both
  sides). Full verbatim excerpts in `tdd/verification.md`.
- GREEN (commit `bd227e44`, fix applied): 19/19 `All tests passed!`

## Regression scope actually run

- The existing #1333 unit contract (same file) — green, unchanged.
- The #1333 slow driver suite `bug_1333_refactor_reproof_retry_test.dart`
  (`-P regression -j 1`) — 4/4 green: infra detection for ACTUAL crashes
  (exit 255 + kernel signature, ENOENT variants) and the retry loop contract
  are intact; B5 pins that a genuine red still regresses IMMEDIATELY.
- The classifier's real consumer flow: `corpus_economics/
  incremental_verify_test.dart` (the `zfa tdd refactor` scoped re-proof
  driver) — green.
- The chunked fast tier over `test/plugins/tdd` (15 chunks: 7 subfolder
  chunks + 8 batches of the 93 loose root files, kernel caches cleared
  between chunks per the house disk convention) — 1,218 passed / 0 failed;
  `test/plugins/tdd/scenarios` is an all-slow folder (exit 79, `No tests
  ran` under the fast profile — the house-documented expectation).
- `dart analyze` on the changed pair — `No issues found!`
- `dart format --output=none --set-exit-if-changed` — exit 0 (one cosmetic
  const-string reformat was applied during the green phase).
