# Bug Fix: the kernel-cache signature scan skips reporter progress lines and requires same-line crash evidence for the bare phrase

- **Slug**: 1524-reproof-classifier-matches-own-test-name
- **Fixed**: 2026-09-12
- **Assessment**: ./assessment.md
- **Test**: ./test.md
- **Status**: applied
- **TDD artifacts**: `tdd/test-list.md`, `tdd/verification.md` (this directory) — red-green evidence from the real runs.

## Summary

A `dart test` reporter progress line is now NEVER crash evidence. The
kernel-cache signature scan (`hasKernelCacheSignature`,
`kernelCacheSignatureLine`) skips every reporter progress line
(`mm:ss +N [-M] [~K]: …` grammar — per-test status lines and the summary
lines in the same shape) BEFORE matching, and the bare "cannot retrieve
length of file" alternative requires crash evidence (`.dill`,
`dart_test.kernel`, `enoent`, `errno 2`, `no such file`, `failed`)
co-occurring on the same line. A genuine red re-proof is no longer hijacked
into the infra retry loop by the classifier's own passing test name echoed
into the transcript.

Previously the bare phrase matched inside the test name (and the name also
carries `dart_test.kernel … errno 2`, matching the neighboring alternatives
too), so every full-suite re-proof transcript classified `infraRunner` and
burned all `_maxReproofRetries` (~30 min each).

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/services/reproof_failure_classifier.dart` | added `_reporterProgressLine` + `_isReporterProgressLine` (private, bug #1524 grammar) | `^\s*\d{1,2}:\d{2}\s+(?:[+\-~]\d+\s*)+:` — the expanded-reporter status-line shape: elapsed time, then one or more `+passed` / `-failed` / `~skipped` counter tokens, then `:`. Covers `00:00 +0:`, `00:01 +0 -1:`, `10:22 +2918 ~1:` and the summary lines. |
| `lib/src/plugins/tdd/services/reproof_failure_classifier.dart` | `hasKernelCacheSignature` scans line-by-line, skipping progress lines first | All signature alternatives are line-local (`[^\n]*` never crosses a line), so per-line scanning of non-progress lines is equivalent to whole-transcript matching minus the poison. `kernelCacheSignatureLine` gets the same skip (diagnostics stay consistent with the verdict). |
| `lib/src/plugins/tdd/services/reproof_failure_classifier.dart` | bare-phrase alternative gained a same-line crash-evidence lookahead | `cannot retrieve length of file(?=[^\n]*(?:\.dill\|dart_test\.kernel\|enoent\|errno 2\|no such file\|failed))` — the same evidence vocabulary the `dart_test.kernel` alternatives already require; the doc comment's rule is now true for every alternative. |
| `lib/src/plugins/tdd/services/reproof_failure_classifier.dart` | doc comments updated (library decision order + grammar) | Record the bug #1524 rule where the next editor will look. |
| `test/plugins/tdd/reproof_failure_classifier_test.dart` | new group `classifyReproofFailure — poison test-name progress line (bug #1524)`, 5 tests | The poison constant embeds the classifier's own group + test name in reporter progress grammar. See ./test.md. |

`classifyReproofFailure`'s decision order, the retry loop, the refactor
command and the state machine are UNTOUCHED (the issue's hard constraints)
— the fix lives entirely in the signature scan that decision step 3 calls.

## Diff highlights

The load-bearing guard, at the scan site:

```dart
bool hasKernelCacheSignature(String output) {
  for (final line in output.split('\n')) {
    if (_isReporterProgressLine(line)) continue; // bug #1524
    if (_kernelCacheSignature.hasMatch(line)) return true;
  }
  return false;
}
```

and the bare-phrase guard:

```dart
final RegExp _kernelCacheSignature = RegExp(
  r'cannot retrieve length of file'
  r'(?=[^\n]*(?:\.dill|dart_test\.kernel|enoent|errno 2|no such file|failed))'
  r'|dart_test\.kernel[^\n]*(?:enoent|errno 2|no such file|cannot|failed)'
  r'|(?:enoent|errno 2|no such file|cannot|failed)[^\n]*dart_test\.kernel'
  r'|\.dill[^\n]*(?:enoent|errno 2|no such file)'
  r'|(?:enoent|errno 2|no such file or directory)[^\n]*\.dill',
  caseSensitive: false,
);
```

## Frozen surfaces (verified untouched)

- `classifyReproofFailure` — byte-identical body; only the doc comment above
  the library changed.
- The retry loop (`bug_1333_refactor_reproof_retry_test.dart` slow driver
  suite stays green 4/4: B3 infra retry, B4 retries-exhausted →
  `runner-error`, B5 genuine-red-immediate-regression, B6 clean green).
- `parseFailingTestNames` — intentionally still PARSES progress lines
  (failing `[E]` names live on them); the skip applies only to the
  crash-signature scan.
- `reproofOutputTail` — untouched.
