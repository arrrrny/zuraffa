# Tasks — Spec 1333 refactor false regression transient runner

Dependency-ordered, MVP first. Every behavior task is written as a failing
test FIRST (tdd/test-list.md) before its implementation lands.

## Phase A — classification core (MVP)

- [ ] T001. Unit: pure re-proof failure classifier
      (`test/plugins/tdd/reproof_failure_classifier_test.dart`,
      service `lib/src/plugins/tdd/services/reproof_failure_classifier.dart`).
      Matrix: not-started / timeout / kernel-cache signature / exit 255 →
      `infraRunner`; exit 1 with `[E]` names → `regression`; unparseable
      non-infra non-zero → `regression`; tail truncation keeps whole lines
      and marks truncation. Traces FR-1, FR-3 (tail), AS-5.

## Phase B — retry + diagnostics on the refactor step

- [ ] T002. CLI: a single infra re-proof failure is retried once with a
      kernel-cache clear and the run completes green — outcome
      clean/refactored, exit 0, 3 suite invocations, `.dart_tool/test/`
      marker and `$TMPDIR/dart_test.kernel.*` marker cleared.
      Traces FR-1, FR-2, AS-1.
- [ ] T003. CLI: infra failures exhausting 2 retries yield
      `outcome=runner-error` (never regression), 4 suite invocations, and a
      cycle-log diagnostic entry (`exit 255`, `re-proof retries: 2`,
      truncated tail). Traces FR-1, FR-2, FR-3, AS-2.
- [ ] T004. CLI: genuine assertion failure (exit 1, `[E]` names) regresses
      IMMEDIATELY — outcome=regression, 2 suite invocations (no retry),
      cycle-log diagnostic entry (`re-proof verdict: regression (exit 1)` +
      tail). Traces FR-4, AS-3.
- [ ] T005. CLI: green clean no-op evidence entry carries
      `re-proof verdict: green (exit 0)` + retries count + output tail
      (FR-3 on the clean verdict). Traces FR-3, AS-4.

## Phase C — hardening

- [ ] T006. Regression pin: the pre-existing refactor suites stay green
      (`refactor_command_test.dart`, `bug_922_refactor_preflight_baseline_test.dart`,
      `bug_1311_refactor_receipt_refresh_test.dart`) — run ONLY these files
      (disk ceiling; never the full suite).
- [ ] T007. `dart analyze` clean on changed files; `dart format .` leaves
      zero formatting diffs.
