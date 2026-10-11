# TDD Test List: 1524-reproof-classifier-matches-own-test-name

Bug #1524 — the re-proof failure classifier must never treat a `dart test`
reporter progress line (which echoes test names, including the classifier's
OWN signature-named passing test) as kernel-cache crash evidence. Red-green
over the pure classifier; the retry loop, the refactor command and the state
machine are frozen by the issue's hard constraints.

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | `hasKernelCacheSignature` returns false for a reporter progress line that quotes the issue #1333 signature verbatim (the classifier's own passing test name echoed by `dart test`) | FR-1 (bug #1524) | DONE |
| U2 | `classifyReproofFailure` classifies a genuine red re-proof transcript CONTAINING the poison progress line as `regression` (exit 1, parseable `[E]` name, Expected/Actual body), never `infraRunner` | FR-4 (bug #1524) | DONE |
| U3 | `kernelCacheSignatureLine` returns null for the poisoned red transcript — diagnostics agree with the verdict | FR-3 (bug #1524) | DONE |
| U4 | The canonical crash line (`Cannot retrieve length of file: …dart_test.kernel…dill (errno 2)`, NOT a progress line) still classifies `infraRunner` when the poison line is present in the same transcript — the progress-line skip must not swallow genuine crash evidence | FR-1 / AS-5 (over-filtering guard) | DONE |
| U5 | The bare phrase `cannot retrieve length of file` on a non-progress line WITHOUT same-line crash evidence (`.dill` / `dart_test.kernel` / `enoent` / `errno 2` / `no such file` / `failed`) is not crash evidence | FR-1 (bug #1524, issue option 2) | DONE |
| U6 | The existing #1333 contract is unchanged: canonical sentence + `.dill` errno 2 → infra (any exit); `.dill` + ENOENT without the sentence → infra; `dart_test.kernel` without same-line evidence → NOT infra; `Failed to open dart_test.kernel…` → infra; exit 255 → infra; timeout / process-start failure → infra; exit 1 parseable red / unparseable red / other non-zero → regression | FR-1 / FR-4 (regression pins, #1333 + #922) | DONE |
| U7 | The #1333 slow driver contract is unchanged: B3 infra re-proof retried with a kernel-cache clear; B4 exhausted retries → `runner-error`; B5 genuine assertion failure regresses IMMEDIATELY; B6 clean green records the verdict | spec 1333 driver (regression tier) | DONE |

## Notes

- U1–U5 are the new group
  `classifyReproofFailure — poison test-name progress line (bug #1524)` in
  `test/plugins/tdd/reproof_failure_classifier_test.dart` (fast tier, pure).
- U6 is the pre-existing suite in the same file — must stay green untouched.
- U7 is `test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart`
  (`dart test -P regression -j 1`, the issue #1308 driver-suite convention).
- The classifier's real consumer flow is covered by
  `test/plugins/tdd/corpus_economics/incremental_verify_test.dart`
  (the `zfa tdd refactor` scoped re-proof driver) — fast tier, green.
- RED evidence: U1, U2, U3, U5 failed on the unfixed tree for the right
  reason (U2 printed the hijack itself: expected `regression`, actual
  `infraRunner`); U4 passed on both sides by design (it is the
  over-filtering guard, not a defect probe). See `verification.md`.
