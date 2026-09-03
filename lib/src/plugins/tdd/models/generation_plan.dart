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

  /// The generation subprocess was killed by resource pressure — a
  /// signal death (OS OOM killer SIGKILL, or the bounded ceiling turning
  /// runaway allocation into a deterministic in-child abort), classified
  /// per the bug #826 remediation. Transient by nature: a direct re-run
  /// succeeds, no state changed. Non-zero exit, no green entry.
  resourceLimit('resource-limit'),

  /// The generation subprocess outlived its hard deadline and was killed
  /// (bug #742 deadline, classified per bug #826). Non-zero exit, no
  /// green entry.
  timeout('timeout'),

  /// The behavior's generation plan resolves to an empty inner
  /// `zfa make` plan ("No active plugins to run.") — there is nothing to
  /// generate, so the make records a no-op WITHOUT attempting the
  /// subprocess (bug #826 remediation). The run loop defers it to phase 2
  /// exactly like `unexpressible`. Non-zero exit, no green entry.
  noOp('no-op'),

  /// Suite guard found NEW failures.
  /// Non-zero exit, no green entry.
  regression('regression'),

  /// The target test is a SCAFFOLDED widget test (issue #912 defect 3):
  /// its scenario assertions are placeholder finders (marked
  /// `zfa:tdd: scaffolded` by the widget template), so a green proves
  /// nothing about the scenario — a bare SizedBox() would pass it. The
  /// behavior is EXCLUDED from contract-green accounting: non-zero exit,
  /// no green entry; the remedy is concrete scenario finders + marker
  /// removal, then re-run make.
  scaffolded('scaffolded'),

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

  /// True when the step was killed by the per-command timeout (bug #742).
  /// The process launched but outlived the deadline — a tooling failure,
  /// not a generation failure.
  final bool timedOut;

  /// Why the step's process died, when it died by kill rather than by its
  /// own exit (bug #826): [GenerationKillClass.timeout] when our deadline
  /// fired, [GenerationKillClass.resourceLimit] when the OS or the bounded
  /// ceiling killed it (the SIGKILL/OOM class — Dart reports a
  /// signal-killed child as a negative exit code). [GenerationKillClass.none]
  /// for every ordinary exit, including ordinary failures.
  final GenerationKillClass killClass;

  /// Resource telemetry around the step's subprocess (bug #826): the
  /// spawning process's RSS just before/after the child ran and the
  /// child's wall-clock duration. Surface in the verdict JSON for
  /// observability; never used in decisions.
  final StepTelemetry? telemetry;

  const GenerationStep({
    required this.command,
    required this.exitCode,
    required this.output,
    required this.purpose,
    this.timedOut = false,
    this.killClass = GenerationKillClass.none,
    this.telemetry,
  });

  /// The machine-parseable verdict class for a killed step
  /// (`resource-limit` or `timeout`), null for every ordinary exit —
  /// a killed step is never graded as a bare `generation-error` (bug #826).
  String? get verdictLabel => switch (killClass) {
    GenerationKillClass.none => null,
    GenerationKillClass.timeout => 'timeout',
    GenerationKillClass.resourceLimit => 'resource-limit',
  };

  /// The JSON verdict for a killed step: the classification, the exact
  /// exit code, and the resource telemetry (bug #826 remediation 4).
  /// Empty for ordinary exits (they keep their honest failure records).
  Map<String, dynamic> verdictJson() => {
    if (verdictLabel != null) 'verdict': verdictLabel,
    'exitCode': exitCode,
    'timedOut': timedOut,
    'rssBeforeKb': telemetry?.rssBeforeKb,
    'rssAfterKb': telemetry?.rssAfterKb,
    'wallClockMs': telemetry?.wallClockMs,
    'command': command,
  };

  @override
  String toString() =>
      'GenerationStep($purpose: exit=$exitCode cmd=$command'
      '${verdictLabel == null ? '' : ' verdict=$verdictLabel'})';
}

/// Why a killed generation step died (bug #826). Only kills are
/// classified; an ordinary non-zero exit stays an unclassified, honest
/// generation failure.
enum GenerationKillClass {
  /// The process exited by itself (exit code — zero or not).
  none,

  /// Our per-step deadline fired and we killed the child (bug #742 path).
  timeout,

  /// The child died by signal — the OS OOM killer (SIGKILL, exit -9 on
  /// POSIX) or the bounded ceiling turning runaway allocation into a
  /// deterministic in-child abort. The transient, re-runnable class.
  resourceLimit,
}

/// Resource telemetry around one generation step's subprocess (bug #826).
class StepTelemetry {
  /// The spawning process's RSS (KB) just before the child spawned.
  final int rssBeforeKb;

  /// The spawning process's RSS (KB) just after the child completed.
  final int rssAfterKb;

  /// The child's wall-clock duration in milliseconds.
  final int wallClockMs;

  const StepTelemetry({
    required this.rssBeforeKb,
    required this.rssAfterKb,
    required this.wallClockMs,
  });

  Map<String, dynamic> toJson() => {
    'rssBeforeKb': rssBeforeKb,
    'rssAfterKb': rssAfterKb,
    'wallClockMs': wallClockMs,
  };

  @override
  String toString() =>
      'StepTelemetry(rss: ${rssBeforeKb}KB -> ${rssAfterKb}KB, '
      'wall: ${wallClockMs}ms)';
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
