/// `RedClassification` + `RunRecord` — the seven-way outcome of a
/// `zfa tdd verify-red` run (spec 046-tdd-verify-red, FR-004, T003;
/// seventh class added by issue #831).
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
  ),

  /// A platform-channel call never resolved (issue #831): the fake is
  /// missing or misconfigured, or the channel never answered — the
  /// transcript carries MissingPluginException / a channel-scoped
  /// TimeoutException / PlatformException(channel-error) WITHOUT an
  /// assertion signature. A harness/config failure, never a certified
  /// red: the behavior was not honestly observed through an assertion.
  channelTimeout(
    'channel-timeout',
    'the platform-channel call never resolved — generate the certified '
        'fake and its committed scenario with `zfa tdd fake <channel> '
        '--behavior <behavior-id>`, extend the scenario script, then '
        're-run `zfa tdd verify-red <behavior-id>`',
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

  /// True when the runner was killed by the per-command timeout (bug #742).
  /// The process DID launch; it outlived the deadline and was killed
  /// (SIGKILL). Classified as [RedClassification.runnerError] — a timeout is
  /// an infrastructure failure, never a certified red.
  final bool timedOut;

  const RunRecord({
    required this.command,
    required this.exitCode,
    required this.output,
    required this.startedProcess,
    this.testCount,
    this.timedOut = false,
  });

  @override
  String toString() =>
      'RunRecord(command: $command, exit: $exitCode, '
      'started: $startedProcess, tests: $testCount)';
}
