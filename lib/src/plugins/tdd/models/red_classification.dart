/// `RedClassification` + `RunRecord` — the six-way outcome of a
/// `zfa tdd verify-red` run (spec 046-tdd-verify-red, FR-004, T003).
///
/// Exactly one class per run. `assertion` is the only class that
/// certifies honest red; every other class is a rejection with a
/// remediation hint (FR-007).
library;

/// The six-way outcome classification of a verification run.
enum RedClassification {
  /// Honest red: the target test failed through an assertion.
  assertion('assertion', 'the failure is the expected honest red'),

  /// The test or its subject did not compile.
  compileError(
    'compile-error',
    'fix the compile error in the test or its subject, then re-run '
        '`zfa tdd verify-red <behavior-id>`',
  ),

  /// The test file (or an import) could not be loaded.
  loadError(
    'load-error',
    'restore the missing test file or import, then re-run '
        '`zfa tdd verify-red <behavior-id>`',
  ),

  /// The target test was skipped or pending.
  skipped(
    'skipped',
    'remove the skip/pending marker from the target test, then re-run '
        '`zfa tdd verify-red <behavior-id>`',
  ),

  /// The target test passed without an implementation.
  unexpectedGreen(
    'unexpected-green',
    'the test already passes; tighten its assertion or check the right '
        'test is registered, then re-run `zfa tdd verify-red <behavior-id>`',
  ),

  /// The runner did not execute exactly the target test (infrastructure
  /// failure, timeout, blended or unexplained run).
  runnerError(
    'runner-error',
    'the runner did not execute exactly the target test; check the '
        'tdd-profile `single` command and the toolchain, then re-run '
        '`zfa tdd verify-red <behavior-id>`',
  );

  const RedClassification(this.label, this.remediationHint);

  /// Kebab-case label used in the machine-readable summary line (FR-009).
  final String label;

  /// One-line remediation hint printed on rejection (FR-007).
  final String remediationHint;
}

/// The structured input the classifier consumes: everything the runner
/// wrapper captured about one single-test invocation.
class RunRecord {
  /// The resolved runner command, post `{file}`/`{name}` substitution.
  final String command;

  /// The runner's exit code. `-1` when the process never started.
  final int exitCode;

  /// Combined stdout + stderr of the run.
  final String output;

  /// `false` when the executable failed to launch at all.
  final bool startedProcess;

  /// Parsed count of executed tests (passed + failed + skipped).
  /// `null` when the transcript cannot be parsed.
  final int? testCount;

  const RunRecord({
    required this.command,
    required this.exitCode,
    required this.output,
    required this.startedProcess,
    this.testCount,
  });

  @override
  String toString() =>
      'RunRecord(command: $command, exit: $exitCode, '
      'started: $startedProcess, tests: $testCount)';
}
