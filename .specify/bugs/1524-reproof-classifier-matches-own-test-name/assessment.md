# Bug Assessment: `classifyReproofFailure` matches its own test name — every red re-proof becomes an infra retry loop

- **Slug**: 1524-reproof-classifier-matches-own-test-name
- **Created**: 2026-09-12
- **Source**: https://github.com/arrrrny/zuraffa/issues/1524
- **Verdict**: valid, reproduced deterministically at the unit level
- **Severity**: high (a genuine red refactor re-proof can NEVER be certified: the infra retry loop burns all `_maxReproofRetries` full-suite runs, ~30 min each, and ends `runner-error` — observed 10× in cycle-log, always at `+2918 ~1`, the fixed position of the poison test)

## Report

`classifyReproofFailure` (`lib/src/plugins/tdd/services/reproof_failure_classifier.dart:40-47`)
misclassifies **every** red refactor re-proof as an infrastructure failure,
because the FIRST alternative of `_kernelCacheSignature` is the bare phrase
`cannot retrieve length of file` — and that exact phrase is part of the name
of one of the classifier's OWN passing tests:

```
infra tier (FR-1 / AS-5) the issue #1333 signature: "Cannot retrieve length of file" + dart_test.kernel .dill errno 2
```

`dart test` prints every test's name as a reporter progress line, so any
FULL-suite re-proof transcript contains that line. The signature scan matches
it, step 3 of the decision order returns `ReproofFailureClass.infraRunner`,
and a genuinely red re-proof is routed into the kernel-cache-clear retry loop
instead of being declared a regression.

## Symptom

`zfa tdd refactor` / `zfa tdd run` on a red re-proof: instead of the
immediate `regression` declaration (FR-4), the runner retries the FULL suite
`_maxReproofRetries` times with a kernel-cache clear between attempts
(~30 min per full-suite run on this repo), then ends `runner-error`. The
cycle-log shows the loop always stalling at the same counter position
`+2918 ~1` — the fixed position of the poison test in the full suite, i.e.
the moment its name is echoed into the transcript.

## Reproduction (deterministic, unit level)

```dart
const genuineRed = '00:01 +0 -1: test/some_test.dart: a real regression [E]\n'
    '  Expected: 2\n    Actual: 1\nSome tests failed.\n';
const poison =
    '10:22 +2918 ~1: test/plugins/tdd/reproof_failure_classifier_test.dart: '
    '... — infra tier (FR-1 / AS-5) the issue #1333 signature: "Cannot '
    'retrieve length of file" + dart_test.kernel .dill errno 2';

// classify(genuineRed alone)              → regression ✅
// classify(genuineRed + poison)           → infraRunner ❌ (should stay regression)
```

Reproduced for real in this session (commit `ad4d6663`, tests only): the new
poison regression suite ran 4 RED — including
`a genuine red re-proof with the poison line stays a regression` →
`Expected: ReproofFailureClass:<ReproofFailureClass.regression> / Actual:
ReproofFailureClass:<ReproofFailureClass.infraRunner>` — while the 15
pre-existing tests stayed green.

## Root cause (confirmed against the tree)

1. `_kernelCacheSignature`'s first alternative is the bare phrase
   `cannot retrieve length of file` with NO crash-evidence requirement and
   NO progress-line awareness. The doc comment already says "`dart_test.kernel`
   only counts when the same line also carries crash evidence" — the bare
   phrase alternative never got that guard.
2. `hasKernelCacheSignature` scans the WHOLE transcript with one
   `hasMatch`, so the reporter's progress lines are scanned exactly like
   crash output. A progress line that QUOTES a signature (a test name
   describing the #1333 signature — the classifier's own test) is
   indistinguishable from the crash itself under that scan.
3. The poison line matches not only the bare phrase but ALSO the
   `dart_test.kernel … errno 2` alternatives (the test name contains both),
   so guarding the bare phrase ALONE is insufficient — the scan must skip
   reporter progress lines entirely.
4. Decision order step 3 (`kernel-cache signature → infraRunner`) then
   fires before the exit-255 and regression tiers, and the retry loop
   (frozen by this issue's hard constraints) faithfully burns its retries.

## Proposed remediation

Classifier-only (the retry loop, the refactor command and the state machine
are frozen by the issue's hard constraints):

1. Skip `dart test` reporter progress lines (`mm:ss +N [-M] [~K]: …`
   grammar) BEFORE signature matching — in both
   `hasKernelCacheSignature` and `kernelCacheSignatureLine`. Genuine crash
   evidence (the canonical `Cannot retrieve length of file: …dart_test.kernel…dill (errno 2)`
   line) is never printed as a progress line, so nothing real is lost.
2. Require the bare-phrase alternative to co-occur with crash evidence
   (`.dill` / `dart_test.kernel` / `enoent` / `errno 2` / `no such file` /
   `failed`) on the SAME line, making the grammar's doc comment true for
   every alternative.
3. Regression tests: a poisoned genuine-red transcript classifies
   `regression`; a canonical crash line next to the poison line still
   classifies `infraRunner` (over-filtering guard).

## Risks & considerations

- The progress-line skip must not swallow genuine evidence: the existing
  #1333 suite's crash lines carry no progress prefix, and a dedicated test
  pins that a canonical crash line is still infra next to a poison line.
- `parseFailingTestNames` intentionally PARSES progress lines (`[E]` names)
  — untouched; the skip applies only to the crash-signature scan.
- The bare-phrase evidence lookahead uses the same evidence vocabulary the
  `dart_test.kernel` alternatives already use — one wording family, no new
  grammar concepts.
- Exit-255 tier and the timeout / process-start tiers are untouched: a real
  runner crash with a transcript the (now stricter) scan somehow misses is
  still caught by step 4.
