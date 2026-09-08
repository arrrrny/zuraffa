# TDD Test List — Spec 1333 refactor false regression transient runner

One behavior per line, traced to the acceptance scenarios / FRs in spec.md.
Every behavior is written as a failing test FIRST (RED), then made to pass
(GREEN). Red for this feature: pre-fix, the classifier does not exist
(compile error = red-protocol TODO, re-run after skeleton) and the CLI
fixtures observe `outcome=regression` + zero retry invocations where
`infra retry` / `runner-error` is required.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | Exit 255, kernel-cache transcript signatures (`Cannot retrieve length of file`, `dart_test.kernel`, `.dill`+ENOENT/errno-2), not-started, and timeout each classify `infraRunner`; exit 1 with `[E]` failing-test names and unparseable non-infra non-zero transcripts classify `regression` | FR-1 / AS-5 | test/plugins/tdd/reproof_failure_classifier_test.dart |
| B2 | `reproofOutputTail` keeps the last 2000 chars on whole-line boundaries and marks a truncated tail with `...(truncated)` | FR-3 / AS-5 | test/plugins/tdd/reproof_failure_classifier_test.dart |
| B3 | A re-proof that infra-fails ONCE (exit 255 + kernel signature) is retried with the kernel cache cleared and the run completes green: outcome clean/refactored, exit 0, exactly 3 suite invocations, `.dart_tool/test/probe.kernel` and the `$TMPDIR/dart_test.kernel.*` probe deleted | FR-1, FR-2 / AS-1 | test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart |
| B4 | Infra failures on EVERY re-proof attempt exhaust 2 retries → `outcome=runner-error` (NOT regression), exactly 4 suite invocations, and the cycle log carries `re-proof verdict: infra-runner-error (exit 255)`, `re-proof retries: 2`, and a truncated output tail | FR-1, FR-2, FR-3 / AS-2 | test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart |
| B5 | A genuine assertion re-proof failure (exit 1 + `[E]` names) regresses IMMEDIATELY: outcome=regression, exactly 2 suite invocations (no retry), cycle log carries `re-proof verdict: regression (exit 1)` + tail | FR-4 / AS-3 | test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart |
| B6 | A clean green no-op refactor evidence entry carries `re-proof verdict: green (exit 0)`, `re-proof retries: 0`, and a non-empty output tail block | FR-3 / AS-4 | test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart |

## Red protocol

Run per file, never the full suite (disk ceiling):

```
dart test test/plugins/tdd/reproof_failure_classifier_test.dart          # B1-B2 (fast)
dart test test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart     # B3-B6 (CLI, slow tier)
```

Expected RED evidence (pre-fix): B1/B2 — the classifier service does not
exist (compile error counts as red-protocol TODO, re-run after skeleton).
B3/B4 — `outcome=regression` (transient infra counted as a genuine
regression, the issue signature) and invocation counts 2/2 instead of 3/4.
B5 — expected GREEN pre-fix on the verdict (regression already happens) but
RED on the invocation count assertion is not applicable (no retry pre-fix)
and RED on the cycle-log diagnostic entry (no failure-path record — the
issue's "not appended to cycle-log.md" signature). B6 — RED on the missing
`re-proof verdict:` line (pre-fix evidence carries only `re-proof: green`).
