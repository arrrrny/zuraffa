# Plan — Spec 1333 refactor false regression transient runner

## Technical Context

- Feature: `zfa tdd refactor` re-proof (the post-pass suite verdict in
  `lib/src/plugins/tdd/commands/refactor_command.dart`).
- Failure domain: the re-proof shells out to `dart test` through
  `SingleTestRunner.runSuite` and receives a `SuiteRunRecord`
  (command / exitCode / combined stdout+stderr output / startedProcess /
  timedOut). The Dart incremental kernel cache race surfaces as exit 255
  with `Cannot retrieve length of file ... dart_test.kernel.<path>.dill`
  (errno 2, ENOENT) in the transcript — NOT as an assertion failure
  (exit 1, `mm:ss +N -M: <test name> [E]` lines plus the failure block).
- Classification today: `!startedProcess || exitCode != 0` → baseline
  tolerance check (issue #922) → else `RefactorOutcome.regression`
  immediately. No infra tier, no retry, no cycle-log record on failure.
- Evidence store: `CycleLog` (append-only, chain-hashed sha256 over the
  certified facts; capturedOutput is freeform inside a fenced block and is
  NOT part of the chain payload — extending it is schema-safe at v1).
- Constraints honored: only the refactor step's re-proof classification,
  retry, and diagnostics change; the core engine cycle, gen/make/compose/
  view, preflight, pass registry, receipt refresh (#1311), and verify gate
  semantics are untouched.

## Approach

1. **Pure classifier** — `lib/src/plugins/tdd/services/reproof_failure_classifier.dart`
   (the `red_classifier.dart` lesson: all transcript-grammar parsing lives
   in one pure, unit-testable place):
   - `ReproofFailureClass { infraRunner, regression }`.
   - `classifyReproofFailure({exitCode, output, startedProcess, timedOut})`
     — decision order: not-started → timeout → kernel-cache signature →
     exit 255 → infra; else regression (immediate).
   - `kernelCacheSignature(String)` — `Cannot retrieve length of file` /
     `dart_test.kernel` / `.dill`+ENOENT/errno-2 (case-insensitive).
   - `parseFailingTestNames(String)` — the `[E]` line grammar, moved here
     so the command's preflight and the classifier share ONE copy.
   - `reproofOutputTail(String, {maxChars = 2000})` — whole-line tail with
     a `(truncated)` marker.
2. **Retry loop** — in the re-proof block: while the failure classifies
   infra AND retries < 2: clear the dart test kernel cache
   (`<project>/.dart_tool/test/` recursive; `$TMPDIR/dart_test.kernel.*`
   files, best-effort) and re-run the suite. Timeouts are excluded from the
   retry (bug #742 semantics unchanged: larger `--timeout`, no re-run).
3. **Outcome mapping** — infra exhausted → `RefactorOutcome.runnerError`
   (never regression); non-infra failures keep the #922 tolerance check and
   the immediate regression verdict.
4. **Diagnostics (FR-3)** — a `_appendReproofDiagnostics` helper appends a
   `CycleLogEntry(kind: refactor)` carrying
   `re-proof verdict: <verdict> (exit <code>)`, `re-proof retries: <n>`,
   and the truncated transcript tail on: infra-exhausted, regression, and
   timeout paths (best-effort: try/catch with a loud warning). Green-path
   evidence entries gain the same verdict line, retry count, and tail
   alongside the existing `preflight:`/`re-proof:`/`applied:` fields.

## Test strategy

- Unit (fast, no tag): the pure classifier matrix + tail truncation.
- CLI (slow tier, TddFixture + scripted flaky suite via `spyDir` scripts,
  the bug #922 two-phase pattern): AS-1 retry recovers, AS-2 exhaustion →
  runner-error + diagnostics, AS-3 assertion regression immediate (no
  retry), AS-4 diagnostics on the clean verdict. Invocation counting via a
  counter file; kernel-cache clear proven via pre-seeded
  `.dart_tool/test/probe.kernel` and `$TMPDIR/dart_test.kernel.<unique>`
  markers that must be gone after the run.
- Per-run protocol: never the full suite (disk ceiling); only the two files
  above + the pre-existing refactor suites they must not regress.

## Risks

- Deleting `$TMPDIR/dart_test.kernel.*` can race a concurrent `dart test`
  kernel build — accepted: it is the issue's sanctioned remedy, the window
  is milliseconds, kernels are regenerated on demand, and the retry tier
  itself is the mitigation for the same race in production.
- `captureOutput` content is freeform — no parser depends on the new lines
  (chain hash excludes it; doctor renders it verbatim).
