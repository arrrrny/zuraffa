/// Value objects for the generation-only green step of the TDD loop
/// (spec 047-tdd-make, T002; data-model.md).
///
/// A [GenerationPlan] is either expressible (steps non-empty, ending in
/// a `build` step) or carries an `unexpressibleReason` naming the
/// unmet capability in behavior terms — never both.
///
/// A [GenerationStepSpec] is one pipeline invocation: the `args` to
/// pass after the `zfa` entrypoint, plus a human-readable `purpose`
/// tying it back to the behavior.
///
/// A [GenerationStep] is an executed [GenerationStepSpec]: the full
/// resolved command line, exit code, captured stdout+stderr, and the
/// spec it executed.
library;

/// Outcome of a `make` run — drives the summary line + exit code +
/// green-entry decision (spec FR-010, data-model.md table).
enum MakeOutcome {
  /// Generated implementation, target test passes, suite guard clean.
  /// Exit 0, green entry appended.
  green('green'),

  /// No red evidence in cycle log for the behavior.
  /// Non-zero exit, no green entry.
  notCertifiedRed('not-certified-red'),

  /// Target test already green before generation — the skip transition
  /// (issue #694, amending US2.AC3): generation never runs, the suite is
  /// re-certified with no NEW failures, a green evidence entry with an
  /// explicitly empty generation block is appended, exit 0.
  skipped('skipped'),

  /// Planner cannot map behavior to pipeline steps.
  /// Non-zero exit, no green entry.
  unexpressible('unexpressible'),

  /// A pipeline step failed or produced non-compiling output.
  /// Non-zero exit, no green entry.
  generationError('generation-error'),

  /// Suite guard found NEW failures.
  /// Non-zero exit, no green entry.
  regression('regression'),

  /// Runner/profile/tooling failure.
  /// Non-zero exit, no green entry.
  runnerError('runner-error');

  const MakeOutcome(this.label);

  /// Kebab-case label used in the machine-readable summary line
  /// (`make: behavior=<id> outcome=<label> feature=<f>`).
  final String label;
}

/// One step in a [GenerationPlan]: the args to pass after the `zfa`
/// entrypoint, plus a purpose describing what behavior it serves.
class GenerationStepSpec {
  /// Args passed after the `zfa` entrypoint, e.g.
  /// `['entity', 'create', 'User', '--fields=email']`.
  final List<String> args;

  /// Human-readable purpose tying this step to the behavior, e.g.
  /// `'create entity User'`.
  final String purpose;

  const GenerationStepSpec({required this.args, required this.purpose});

  @override
  String toString() => 'GenerationStepSpec($purpose: zfa ${args.join(' ')})';
}

/// One executed pipeline step — captured for audit (FR-006).
class GenerationStep {
  /// The full resolved command line, e.g. `zfa entity create User`.
  final String command;

  /// The exit code of the step. `-1` when the process failed to start.
  final int exitCode;

  /// Combined stdout + stderr of the step.
  final String output;

  /// The purpose inherited from the spec.
  final String purpose;

  const GenerationStep({
    required this.command,
    required this.exitCode,
    required this.output,
    required this.purpose,
  });

  @override
  String toString() => 'GenerationStep($purpose: exit=$exitCode cmd=$command)';
}

/// A behavior → pipeline mapping. Either expressible (steps non-empty,
/// ending in `build`) or unexpressible (`unexpressibleReason` set);
/// never both (FR-005 validation rule).
class GenerationPlan {
  final String behaviorId;
  final String feature;
  final String sourceCriterion;
  final List<GenerationStepSpec> steps;
  final String? unexpressibleReason;

  GenerationPlan({
    required this.behaviorId,
    required this.feature,
    required this.sourceCriterion,
    required this.steps,
    this.unexpressibleReason,
  }) : assert(
         (steps.isNotEmpty && unexpressibleReason == null) ||
             (steps.isEmpty && unexpressibleReason != null),
         'A plan is either expressible (steps non-empty) or carries an '
         'unexpressibleReason — never both, never neither.',
       );

  bool get isExpressible => steps.isNotEmpty;

  @override
  String toString() => isExpressible
      ? 'GenerationPlan($behaviorId, ${steps.length} steps)'
      : 'GenerationPlan($behaviorId, unexpressible: $unexpressibleReason)';
}
