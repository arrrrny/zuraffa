# TDD Verification: 1524-reproof-classifier-matches-own-test-name

- **Slug**: 1524-reproof-classifier-matches-own-test-name
- **Verified**: 2026-09-12
- **Method**: real red → green over the pure classifier unit suite, plus the
  #1333 slow driver suite (`-P regression`), the classifier's real consumer
  flow (the `zfa tdd refactor` scoped re-proof driver), the chunked fast
  tier over `test/plugins/tdd`, and the analyzer/format gates.
- **Result**: verified — every check below is from an ACTUAL run in this
  session on the fix branch (Dart 3.13.3 stable, linux_x64); nothing is
  copied or back-dated.

## Checks

| # | Check | Command | Result | Evidence |
|---|-------|---------|--------|----------|
| 1 | Analyzer, changed files | `dart analyze lib/src/plugins/tdd/services/reproof_failure_classifier.dart test/plugins/tdd/reproof_failure_classifier_test.dart` | PASS | `No issues found!` |
| 2 | RED (pre-fix, commit `ad4d6663` + tests only) | `dart test test/plugins/tdd/reproof_failure_classifier_test.dart` | FAIL × 4 — the RIGHT failures | `00:00 +15 -4: Some tests failed.` — see "Red evidence" below |
| 3 | GREEN (post-fix, commit `bd227e44`) | same as #2 | PASS | `00:00 +19: All tests passed!` |
| 4 | Consumer flow — `zfa tdd refactor` scoped re-proof driver | `dart test test/plugins/tdd/reproof_failure_classifier_test.dart test/plugins/tdd/corpus_economics/incremental_verify_test.dart` | PASS | `00:20 +29: All tests passed!` |
| 5 | Regression — #1333 slow driver suite (the retry loop contract) | `dart test -P regression -j 1 test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart` | PASS | `00:10 +4: All tests passed!` (B3 infra retried with kernel-cache clear; B4 exhausted retries → `runner-error`; B5 genuine red regresses IMMEDIATELY; B6 clean green verdict) |
| 6 | Chunked fast tier over the affected folder | 15 chunks over `test/plugins/tdd` (7 subfolder chunks + 8 batches of the 93 loose root files, kernel caches cleared between chunks) | PASS (1,218 passed / 0 failed) | per-chunk: commands `+518`, corpus_economics `+53`, models `+81`, theater `+15`, services/ci_referee `+33`, services/tier2_firestore `+33`, loose batches `+77 +34 +43 +73 +75 +51 +102 +30` — every chunk `All tests passed!` |
| 7 | Chunk `test/plugins/tdd/scenarios` | same run | N/A (house-documented) | `No tests ran. / No tests match the requested tag selectors: exclude "slow"` — the folder is all-slow under the fast profile; identical to the expectation recorded in the #1483 verification. Not a failure. |
| 8 | Disk-bounded run note | one folder-wide `dart test test/plugins/tdd` invocation was attempted first and hit `OS Error: No space left on device, errno = 28` in `/tmp/dart_test.kernel.*` at `03:35 +1174 -150` | N/A (environment, not a regression) | ALL 150 failures are `Failed to load … (OS Error: No space left on device, errno = 28)` loader errors — zero assertion failures (`Expected:`/`Actual:` lines: 0). Exactly the hazard `dart_test.yaml` + `tools/run_tests_chunked.sh` document ("a single `dart test test` invocation … ~6.5 GB kernel cache … overflows small disks"); re-run chunked per the house convention (check #6). Ironically the ENOSPC class itself is a #1333-tier infra signature — correctly NOT the bug fixed here. |
| 9 | Format gate | `dart format --output=none --set-exit-if-changed` on the two changed files | PASS | first run flagged the new test group (`Formatted 2 files (1 changed)` — cosmetic const-string wrapping), formatter applied, re-run: `Formatted 2 files (0 changed)`, exit 0 |
| 10 | Kernel-cache hygiene (standing obligation) | `rm -rf .dart_tool/test/ /tmp/dart_test.kernel.*` before AND after every test invocation | DONE | `df -h .` stayed at 8.2 GiB free through the final state; no kernel artifacts left behind |

## Red evidence (check #2, verbatim from the run)

The four RED failures, for the RIGHT reasons:

```
00:00 +10 -1: ... poison ... hasKernelCacheSignature ignores a reporter progress line [E]
  Expected: <false>
    Actual: <true>

00:00 +10 -2: ... a genuine red re-proof with the poison line stays a regression [E]
  Expected: ReproofFailureClass:<ReproofFailureClass.regression>
    Actual: ReproofFailureClass:<ReproofFailureClass.infraRunner>

00:00 +10 -3: ... kernelCacheSignatureLine finds no signature in a poisoned red [E]
  Expected: null
    Actual: '10:22 +2918 ~1: test/plugins/tdd/reproof_failure_classifier_test.dart: classifyReproofFailure — infra tier (FR-1 / AS-5) the issue #1333 signature: "Cannot retrieve length of file" + dart_test.kernel .dill errno 2'

00:00 +11 -4: ... bare phrase without crash evidence on the same line is not infra [E]
  Expected: false
    Actual: <true>

00:00 +15 -4: Some tests failed.
```

Failure #2 IS the issue's defect: a genuine red transcript poisoned by the
classifier's own test-name progress line classifies `infraRunner` instead of
`regression`. Failure #3 shows the diagnostics surface leaking the poison
line. Failures #1/#4 show the bare phrase and its absence-of-evidence case.
The over-filtering guard (`the canonical crash line is still infra next to
the poison line`) passed on BOTH sides by design. The 15 pre-existing tests
(#1333 contract, #922 guard, parse/tail units) stayed green — the new tests
alone failed.

## Green evidence (check #3, verbatim from the run)

```
00:00 +14: ... bare phrase without crash evidence on the same line is not infra
00:00 +15: parseFailingTestNames extracts sorted de-duped names from [E] lines
00:00 +16: parseFailingTestNames returns empty for transcripts without [E] lines
00:00 +17: reproofOutputTail (FR-3) short transcripts pass through trimmed
00:00 +18: reproofOutputTail (FR-3) long transcripts truncate to whole lines with a marker
00:00 +19: All tests passed!
```

## Success criteria

- PROVED: a genuine red re-proof transcript poisoned by the classifier's own
  test-name progress line classifies `regression` (U2) — the hijack is gone.
- PROVED: reporter progress lines are never crash evidence (U1, U3); the
  bare phrase requires same-line crash evidence (U5).
- PROVED: genuine crash evidence is NOT over-filtered — the canonical crash
  line next to a poison line is still `infraRunner` (U4), and the #1333 slow
  driver contract (retry with kernel-cache clear, exhausted-retries →
  `runner-error`, immediate regression, green verdict) is green (U7).
- PROVED: no new analyzer warnings (U-gate #1) and the format gate holds
  (#9).
- SCOPE: the fix touched ONLY
  `lib/src/plugins/tdd/services/reproof_failure_classifier.dart` (the scan)
  and its test file — `classifyReproofFailure`'s body, the retry loop, the
  refactor command and the state machine are byte-identical
  (`git diff HEAD~1 --stat`: 2 files, +58/−15).

## Review-fixes round (the PR #1532 review findings)

Follow-up to the automated review of PR #1532 at `84df97b2`, which raised
four findings (0 🔴 · 0 🟠 · 2 🟡 · 1 🔵 · 1 nit). All four are applied:

| # | Where | Finding | Fix |
|---|-------|---------|-----|
| 1 🟡 | `reproof_failure_classifier_test.dart:189-194` | The over-filtering guard used `exitCode: 255`, so decision step 4 returned `infraRunner` for ANY transcript; the assertion held even if the signature scan missed the crash line. | Guard now uses `exitCode: 1`, so only step 3 — the scan under test — can produce `infraRunner`. |
| 2 🟡 | `reproof_failure_classifier.dart:64` | `failed` (generic prose) guarded the bare-sentence alternative, and the lookahead ran only forward while the doc promised same-line co-occurrence. | `failed` dropped from the sentence alternative; the alternative is now order-independent — a crash-specific token before OR after the phrase, matching the doc. |
| 3 🔵 | `reproof_failure_classifier.dart:46` | `\d{1,2}` capped the reporter minute field at 99, so the progress-line skip stopped applying to runs past 99 minutes — the longest full-suite runs this bug is about. | Widened to `\d+`. |
| 4 nit | `reproof_failure_classifier_test.dart:169-176` | The red transcript literal was duplicated byte-for-byte between the verdict and the diagnostics test. | Extracted one shared `const poisonTranscript`. |

Check #2's "over-filtering guard … passed on BOTH sides by design" note above
is **superseded** by finding 1: with `exitCode: 1` the guard now exercises the
signature scan instead of the exit-255 tier.

### Root cause evidence for finding 3

`test_core` 0.6.20 `lib/src/runner/reporter/expanded.dart` `_timeString`:
`"${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}"`
— the minute field grows past two digits (`100:22`) and there is no `h:mm:ss`
variant, so `\d+` is the complete widening (no hours group needed).

### Re-verification (this round, Dart 3.13.2 on macos_x64)

| Check | Command | Result |
|---|---|---|
| Focused suite | `dart test test/plugins/tdd/reproof_failure_classifier_test.dart` | PASS — `00:00 +21: All tests passed!` (19 → 21: +2 regression tests for findings 2 and 3) |
| Analyzer, both files | `dart analyze …` | PASS — `No issues found!` |
| Format gate, both files | `dart format …` | PASS — `Formatted 2 files (0 changed)` |
| Refactor consumers | `dart test test/plugins/tdd/bug_922_refactor_preflight_baseline_test.dart test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart test/plugins/tdd/corpus_economics/incremental_verify_test.dart` | PASS — `+10: All tests passed!` |
| #1333 retry-loop contract | `dart test -P regression -j 1 test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart` | PASS — `+4: All tests passed!` |
| Broad folder sweep | `dart test test/plugins/tdd` | 3 pre-existing failures in `test/plugins/tdd/commands/` (`bug_993`, `view_command_test` U-V3, `plan_traces_cell_1310` U6) — reproduced on the untouched `84df97b2` head, unrelated to this change; the classifier and its consumers are green. |
