# Issue: reproof failure classifier matches its own test name — every red re-proof becomes an infra retry loop

- **Issue**: #1524
- **URL**: https://github.com/arrrrny/zuraffa/issues/1524
- **State**: OPEN — labels `bug`, `tdd`, opened by `arrrrny`
- **Slug**: 1524-reproof-classifier-matches-own-test-name
- **Assessment**: `.specify/bugs/1524-reproof-classifier-matches-own-test-name/assessment.md`
- **Related**: #1333 (infra detection origin), #922 (baseline tolerance)

## Summary

`classifyReproofFailure` misclassifies **every** red refactor re-proof as an
infrastructure failure, because its kernel-cache signature regex matches the
name of one of its own passing tests. The bare-phrase alternative
`cannot retrieve length of file`
(`lib/src/plugins/tdd/services/reproof_failure_classifier.dart:40-47`) has no
crash-evidence guard and the scan does not skip `dart test` reporter progress
lines — so the transcript line printing the classifier's own test name

```
infra tier (FR-1 / AS-5) the issue #1333 signature: "Cannot retrieve length of file" + dart_test.kernel .dill errno 2
```

is treated as the crash signature itself.

## Reproduction (from the issue)

```dart
const genuineRed = '00:01 +0 -1: test/some_test.dart: a real regression [E]\n'
    '  Expected: 2\n    Actual: 1\nSome tests failed.\n';
const poison =
    '10:22 +2918 ~1: test/plugins/tdd/reproof_failure_classifier_test.dart: '
    '... — infra tier (FR-1 / AS-5) the issue #1333 signature: "Cannot '
    'retrieve length of file" + dart_test.kernel .dill errno 2';

// classify(genuineRed alone)    → regression ✅
// classify(genuineRed + poison) → infraRunner ❌ (should still be regression)
```

`dart test` prints every test's name as a progress line, so any full-suite
transcript contains the poison line.

## Impact

`zfa tdd refactor` / `zfa tdd run` can **never** certify a red re-proof. The
infra retry loop burns all `_maxReproofRetries` full suite runs (~30 min
each) and ends `runner-error`. Observed 10 times in cycle-log, always at
`+2918 ~1` (the fixed position of the poison test).

## Root cause (from the issue)

The bare-phrase alternative `cannot retrieve length of file` matches inside
a test-name line. The doc comment already says "`dart_test.kernel` only
counts when the same line also carries crash evidence" — the bare phrase has
no such guard, and the scan has no progress-line filter at all.

## Expected (from the issue)

Never treat a `dart test` progress line as crash evidence. Either:

1. Skip lines matching reporter progress grammar before matching.
2. Require bare-phrase to co-occur with crash evidence on the same line.
3. Exclude lines matching passing-count progress prefix.

## Hard constraints (from the issue)

- Fix ONLY the classifier in `reproof_failure_classifier.dart`. Do NOT
  change the retry loop, refactor command, or state machine.
- Must pass the existing #1333 suite (don't break infra detection for
  actual crashes).
- Must add a regression test feeding the classifier a transcript containing
  the poison line.
- Must pass `dart analyze` with no new warnings.

## Accepted remediation

Options 1 + 2 together (option 3 is subsumed by the progress-line grammar):
skip reporter progress lines before the signature scan, and require the
bare phrase to co-occur with same-line crash evidence. The poison line
carries `dart_test.kernel … errno 2` INSIDE the quoted test name, so a
bare-phrase guard alone would still be hijacked by the other alternatives —
the progress-line skip is the load-bearing fix.
