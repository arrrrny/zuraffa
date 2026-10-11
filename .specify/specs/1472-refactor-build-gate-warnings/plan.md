# Plan: 1472-refactor-build-gate-warnings

## Technical Context

- **Language/runtime**: Dart 3.11+ (SDK ^3.11.0), pure-Dart package, `dart test`.
- **Feature area**: `zfa tdd refactor` pass registry —
  `lib/src/plugins/tdd/services/refactor_passes.dart` (registry + executor +
  build-pass entrypoint resolution) and its consumer
  `lib/src/plugins/tdd/commands/refactor_command.dart` (misfire-stop grading,
  outcome mapping to the `zfa tdd run` state machine — NOT modified).
- **The gate's single writer**: `BuildCommand.verifyAnalyzeOrFail`
  (`lib/src/commands/build_command.dart` ~625–677) prints the refusal verdict
  line `❌ dart analyze reported <E> error(s) and <W> warning(s) — generated
  code does not compile cleanly.` and exits 1. That line is the machine
  contract the #1407 interpretation reads; this spec reuses it verbatim.
- **The shared parser**: `BuildCommand.countAnalyzerIssues` /
  `BuildCommand.analyzeReportsError` (#1035 line-format contract,
  `^\s*error\s*-\s` multiLine) — the only severity counter either
  interpretation may use.
- **Precedent**: make's errors-only gate (issue #1407,
  `lib/src/plugins/tdd/commands/make_command.dart` ~1540–1573 + 2231–2348):
  re-grades the failed terminal build step when the output proves a
  warnings-only gate refusal; honors the TDD profile opt-out
  `analyze-gate: warnings-blocking`; fail-safe on message/parser disagreement.
- **Binary resolution**: `zfaBuildCommand` (refactor_passes.dart ~373–419)
  delegates to `StepRunner.resolveEntrypoint` with the package tier suppressed
  (bug #717): `--zfa-bin` override → running-from-source → `zfa` on PATH →
  script/executable fallbacks → `'zfa build'` on StateError.
- **Driving version**: `lib/src/version.dart` — `const version` compiled into
  the running CLI; the ground truth "the version driving the run".
- **Test seams**: `ProcessExecutor` fake (`refactor_passes_test.dart`
  `_FakeExecutor`), `TddFixture` + `writeFakeZfaBin(stdoutByArgv/exitByArgv)`
  for CLI-level tests, `CliRunner(exitOnCompletion: false).runCapturing`.

## Design decisions

### D1 — Interpretation fix at the pass registry (SC-1..SC-4), not a `zfa build` change

`RefactorPasses.run()` re-grades a failed `build` pass BEFORE the misfire-stop:
when (a) the pass is `build`, (b) the process started, (c) it was not killed by
the per-pass timeout (bug #742 honesty), and (d) the output is the gate's own
warnings-only refusal (verdict line names 0 errors + ≥1 warnings, AND
`BuildCommand.analyzeReportsError(output)` finds no `error -` lines — the
#1407 double check), the registry logs the accurate counts (SC-3) and
CONTINUES to format → fix. Anything else keeps the byte-identical misfire-stop
(SC-2, SC-4). The recorded `RefactorAction` keeps the true exit code and raw
output — auditability over cosmetically rewritten history.

Rationale: mirrors #1407's interpretation-only shape (the dart analyze
invocation, the build command, and the pipeline are untouched); scoped to the
refactor registry so standalone `zfa build` and make keep their pinned
contracts (SC-7); the alternative OR-arm (running `dart fix --apply` before
`build`) cannot cover warnings `dart fix` cannot clean and would churn four
pinned order tests.

### D2 — Profile opt-out read once by the command, passed into the registry (SC-5)

`refactor_command.dart` reads the TDD profile's `analyze-gate:` key with the
same resolution order make uses (#1407: machine-readable Keys block first,
then legacy frontmatter) and hands `warningsBlocking: true` to
`RefactorPasses`, which then skips the reinterpretation arm entirely. The
default — absent key, explicit `errors-only`, unrecognized value, unreadable
profile — is errors-only (fail-open to the fix, never to the legacy refusal).

### D3 — Version pinning inside `zfaBuildCommand` (SC-6), silence rules per #1184

After the #717-suppressed resolution resolves a candidate entrypoint (the
`--zfa-bin` override wins untouched and is never probed), probe the candidate
with `--version` (shaped: a `.dart` entrypoint runs `dart <path> --version`;
a binary runs `<path> --version`) and parse `zfa v<semver>`:

- version parsed and DIFFERENT from the driving `version` const → re-resolve
  through the UNSUPPRESSED chain (real `Isolate.resolvePackageUri`) and pin
  the build pass to the driving CLI's own entrypoint; log one honest line.
  If the un-suppressed chain cannot resolve (StateError), keep the #717
  candidate (fail-open to current behavior — never crash the refactor).
- version parsed and EQUAL → keep the candidate (#717 contract intact).
- version unprovable (spawn failure, non-zero exit, unrecognized output,
  empty stdout) → keep the candidate. Silence rules: never re-route on
  unprovable input, never break the invocation.

### D4 — No reorder, no build-gate change, no state-machine change

The registry order stays build → format → fix; `verifyAnalyzeOrFail` and
`AnalyzerIssueCounts.blocksGate` are untouched (standalone `zfa build` keeps
warnings-blocking, pinned by `build_command_unit_test.dart`); the refactor
command's outcome mapping (`runner-error` path) is untouched — it simply
stops seeing `passResult.stopped` for warnings-only refusals.

## Risks / mitigations

- **Silent pass of a real defect**: mitigated by the #1407 double check (gate
  verdict line + independent parser), the honest exit code in the recorded
  action, the capped warning sample in the log, and the profile opt-out.
- **Probe spawn in tests**: probing only fires when a candidate resolves
  without `--zfa-bin`; unprovable outputs fall back silently, so existing
  #689/#717 tests (fake zfa scripts printing nothing) keep their assertions.
- **Stale-pin skew**: pinning compares exact semver strings; a mismatch pins
  to the driving entrypoint, whose own version is by definition the driving
  version — no probe recursion.

## Verification strategy

Red → green per behavior against the test list (`tdd/test-list.md`): unit
behaviors through the fake `ProcessExecutor` (hermetic, no subprocesses),
binary-pinning behaviors through fake PATH zfa scripts (real executor,
real `--version` probes), one CLI-level acceptance through `TddFixture` +
`CliRunner.runCapturing` (the issue's exact reproduction shape), then
`dart analyze` on changed files, changed-file pairing tests, `dart format`.
