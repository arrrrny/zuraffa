# Spec 1333 — refactor step reports false "regression" on transient dart test runner failures

GitHub issue: arrrrny/zuraffa#1333
Severity: medium — transient dart test runner failures counted as genuine
regressions; 3 occurrences in a single day (binary 0a9f4487, 2026-09-08).

## Problem

Mid-run, the refactor step for a behavior that just went green reports
`outcome=regression` with `preflight exit: 0` (suite green before the
refactor attempt) and zero diagnostics about which test regressed or why.
The failed re-proof cycle is not appended to `cycle-log.md`. Re-running
immediately (the complete same refactor) reports clean.

Occurrences (binary 0a9f4487, 2026-09-08):

1. spec 011 rerun: `U12:refactor` regression → clean on resume
2. spec 008 rerun: `A17:refactor` regression → clean on resume
3. spec 011 rerun: `U7:refactor` regression → (same signature)

All had `preflight exit: 0` and emitted zero diagnostics.

Root cause: the refactor re-proof shells out to `dart test`
(`refactor_command.dart`, re-proof block) and counts ANY non-zero exit as a
genuine regression. A transient test-runner failure — the Dart incremental
kernel cache race (`Cannot retrieve length of file ...
dart_test.kernel./test.dart_.dill`, errno 2, exit 255) — is
indistinguishable from an assertion failure (exit 1, test name + failure
message). Concurrent `zfa tdd run` processes in the same temp dir make the
race more likely, but it reproduces with a single run. Nothing records the
re-proof transcript when the verdict is a failure, so the cycle log carries
no evidence and the failure is unauditable.

## Locked decisions

1. Fix ONLY the refactor step's re-proof classification and retry logic and
   the diagnostic recording. The core engine cycle, the gen/make/compose/
   view pipeline, the preflight semantics, the pass registry, the
   misfire-stop, the receipt refresh (issue #1311), and the verify gate
   semantics are UNCHANGED.
2. Infra-level runner failures are NOT regressions. They are retried with a
   kernel-cache clear; when retries are exhausted the outcome is
   `runner-error`, never `regression` — a crashed runner cannot certify a
   regression any more than it can certify a pass.
3. Genuine assertion failures regress IMMEDIATELY — no retry. The retry
   exists only for infra signatures; widening it to parseable reds would
   silently burn two extra suite runs on every real regression.
4. Diagnostics are recorded on EVERY re-proof verdict (green, tolerated,
   regression, infra-exhausted, timeout) — append-only via the existing
   `CycleLog`, chain-hashed like every other entry. Failure-path appends
   are best-effort: a cycle-log write error prints a warning and never
   masks the primary verdict.
5. Issue #922 baseline tolerance is unchanged for non-infra failures: a
   re-proof red whose failures are all baseline-recorded stays tolerated.
   An infra failure takes priority over tolerance (a crashed runner cannot
   be waved through by the baseline either).

## Functional requirements

- **FR-1 (infra vs regression classification)**: The refactor re-proof MUST
  classify every failed re-proof attempt into exactly one of: infra-level
  runner failure — process never started, per-command timeout, kernel-cache
  signature in the output (`Cannot retrieve length of file`,
  `dart_test.kernel`, `.dill` with ENOENT/errno-2), or exit 255 — or
  regression (any other non-zero exit, including exit 1 with parseable
  failing-test names and unparseable transcripts). Infra failures are NOT
  regressions.
- **FR-2 (retry on infra failure)**: When a re-proof attempt fails with an
  infra-level runner error, the refactor step MUST retry the re-proof at
  most 2 more times. Before each retry it MUST clear the dart test kernel
  cache — delete `<project>/.dart_tool/test/` recursively and every
  `$TMPDIR/dart_test.kernel.*` file — best-effort (a clear failure never
  crashes the command). A retry that goes green continues the normal green
  path. Retries exhausted with the failure still infra-classified yields
  `outcome=runner-error` (exit non-zero).
- **FR-3 (diagnostic recording)**: The re-proof verdict MUST be appended to
  the feature's `tdd/cycle-log.md` regardless of verdict. The verdict line
  MUST carry the verdict and the final exit code
  (`re-proof verdict: <verdict> (exit <code>)`), plus the retry count and a
  truncated tail (last 2000 chars, whole lines) of the re-proof transcript.
  Green-path entries record the same verdict line and tail alongside the
  existing evidence fields.
- **FR-4 (backward compatibility)**: Genuine assertion failures (exit 1 with
  test name + failure message) continue to classify as regressions
  immediately — no retry. Unparseable red transcripts remain regressions
  (the bug #922 mutation M2 guard holds). Preflight, summary-line contract
  (`refactor: feature=<f> outcome=<o> applied=<n>` as the final stdout
  line), exit-code semantics, test/-immutability, attribution, and the
  issue #922 baseline handoff are unchanged.

## Acceptance scenarios (measurable)

1. **Given** a fixture whose preflight is green and whose re-proof fails
   once with exit 255 and the kernel-cache signature, **when** `zfa tdd
   refactor` runs, **then** the outcome is `clean`/`refactored` with exit 0,
   exactly 3 suite invocations occur (preflight, re-proof, one retry), and
   `<project>/.dart_tool/test/` was cleared before the retry.
2. **Given** a fixture whose preflight is green and whose every re-proof
   attempt infra-fails, **when** `zfa tdd refactor` runs, **then** the
   outcome is `runner-error` (NOT regression), exactly 4 suite invocations
   occur (preflight + initial re-proof + 2 retries), and the cycle log
   carries a verdict line with `exit 255`, `re-proof retries: 2`, and a
   truncated output tail.
3. **Given** a fixture whose preflight is green and whose re-proof exits 1
   with parseable failing-test names, **when** `zfa tdd refactor` runs,
   **then** the outcome is `regression`, exactly 2 suite invocations occur
   (no retry), and the cycle log carries `re-proof verdict: regression
   (exit 1)` plus the output tail.
4. **Given** a plain green refactor (clean no-op), **when** the run
   completes, **then** the cycle-log evidence entry carries
   `re-proof verdict: green (exit 0)` and the output tail (FR-3 holds on
   the clean verdict too).
5. **Given** the pure classifier unit contract, **when** a failed re-proof
   transcript is classified, **then** exit 255 / kernel-cache signature /
   not-started / timeout map to infra-runner, and exit 1 with failing-test
   names (and unparseable non-infra transcripts) map to regression.
