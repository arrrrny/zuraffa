/// `RefactorAction` and `RefactorOutcome` — value objects recorded by
/// `zfa tdd refactor` (spec 048-tdd-refactor, T002; data-model.md).
///
/// Every production-code change applied by the refactor command is captured
/// as a [RefactorAction] with its exact command, exit code, the list of
/// project-relative paths the pass changed (from the before/after tree
/// snapshot diff scoped to that pass), and the captured tool output.
///
/// The command's overall outcome is summarized by exactly one
/// [RefactorOutcome] value:
///
///   - `clean`         — suite green before/after; zero actions applied
///   - `refactored`    — suite green before/after; one or more actions applied
///   - `not-green`     — preflight failed (failing tests named)
///   - `regression`    — post-refactor suite red (regressed tests named)
///   - `runner-error`  — profile/tooling/parse failure
library;

/// The overall outcome of a `zfa tdd refactor` invocation.
///
/// The five values are the contract surface consumed by `zfa tdd run` and
/// CI (spec 048 FR-009). Exit code 0 occurs exactly on `clean` and
/// `refactored`; the other three are non-zero.
enum RefactorOutcome {
  /// Suite green before and after; zero actions needed.
  clean,

  /// Suite green before and after; one or more recorded actions applied.
  refactored,

  /// Preflight failed — at least one test was failing before any pass.
  notGreen,

  /// Post-refactor suite red — a pass broke a previously-green test.
  regression,

  /// Profile missing/unreadable, runner cannot launch, or parse failure.
  runnerError;

  /// Lowercase snake_case label for the summary line + evidence block.
  String get label {
    switch (this) {
      case RefactorOutcome.clean:
        return 'clean';
      case RefactorOutcome.refactored:
        return 'refactored';
      case RefactorOutcome.notGreen:
        return 'not-green';
      case RefactorOutcome.regression:
        return 'regression';
      case RefactorOutcome.runnerError:
        return 'runner-error';
    }
  }

  /// True when exit code 0 is contractually allowed (clean or refactored).
  bool get isGreen =>
      this == RefactorOutcome.clean || this == RefactorOutcome.refactored;
}

/// One recorded tool-driven refactor action.
///
/// Fields mirror data-model.md exactly: `name`, `command`, `exitCode`,
/// `filesChanged`, `output`. A pass that changed no files records
/// `filesChanged: []` (not an error — spec 048 FR-008).
class RefactorAction {
  const RefactorAction({
    required this.name,
    required this.command,
    required this.exitCode,
    required this.filesChanged,
    required this.output,
    this.timedOut = false,
  });

  /// Pass name: `build`, `format`, or `fix`.
  final String name;

  /// The exact invoked command line (e.g. `dart format lib/`).
  final String command;

  /// The pass's process exit code (0 = success).
  final int exitCode;

  /// Project-relative paths the pass changed (from the per-pass before/after
  /// tree-snapshot diff scoped to `lib/`). Empty list when the pass changed
  /// nothing — that is a valid no-op pass.
  final List<String> filesChanged;

  /// Captured tool output (stdout + stderr), trimmed.
  final String output;

  /// True when the pass was killed by the per-command timeout (bug #742):
  /// the pass launched but outlived the deadline (tooling failure).
  final bool timedOut;

  @override
  String toString() =>
      'RefactorAction($name, exit=$exitCode, files=${filesChanged.length})';
}
