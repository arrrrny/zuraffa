/// `CycleLogEntry` entity — one row of `tdd/cycle-log.md`.
///
/// Extended by spec 046-tdd-verify-red (T002): red entries carry the full
/// 8-field evidence contract — behavior id, source criterion, test path,
/// runner command, runner exit code, classification, captured failure
/// output, and timestamp (spec 046 FR-006).
///
/// Extended by spec 048-tdd-refactor (T003): the `refactor` kind records
/// refactor evidence entries. The classification assert is relaxed to
/// `kind != red || classification != null` so refactor (and green) entries
/// may omit the failure classification; only red entries carry one. The
/// `refactorActions` list renders as the `actions:` block per
/// contracts/refactor.md, and `isNoOp` flags a clean no-op entry.
///
/// Existing red/green rendering stays byte-compatible (U10 invariant).
library;

import 'generation_plan.dart';
import 'refactor_action.dart';

enum CycleEntryKind { red, green, refactor }

enum FailureClass {
  assertionFailure,
  compileError,
  loadError,
  unexpectedGreen,
  skipped,
  runnerError,
}

class CycleLogEntry {
  final String behaviorId;
  final CycleEntryKind kind;
  final String runnerCommand;
  final int exitCode;
  final String capturedOutput;
  final FailureClass? classification;

  /// The spec criterion the behavior traces to (e.g. `FR-006`).
  final String sourceCriterion;

  /// The registry-recorded path of the test that produced this entry.
  /// For refactor entries this is the suite scope the command re-proved
  /// green (e.g. `test/plugins/tdd/`).
  final String testPath;

  /// ISO-8601 UTC timestamp of the run.
  final String timestamp;

  /// Refactor actions recorded during this cycle (refactor entries only).
  /// Empty for red/green entries; for refactor entries it lists every
  /// applied pass with its command and filesChanged.
  final List<RefactorAction> refactorActions;

  /// True for a refactor entry that recorded zero actions (a clean no-op).
  /// When true the entry is rendered with a `- no-op: true` marker so the
  /// evidence is explicit about the absence of changes (spec 048 FR-008).
  final bool isNoOp;

  /// Recorded generation steps (green/make entries only). Rendered as the
  /// `generation:` block listing each step's command, exit code, and purpose
  /// in execution order (spec 047 FR-006 / FR-008). Null means the evidence
  /// was not recorded; an empty list is a recorded plan with no steps.
  final List<GenerationStep>? generationSteps;

  /// Suite baseline failure count captured before generation (green entries),
  /// or null when that evidence was not recorded.
  final int? suiteBaselineFailures;

  /// Suite guard failure count from the pre-run baseline snapshot, or null
  /// when that evidence was not recorded.
  final int? suiteGuardFailures;

  /// New failures introduced by the generation, if any (green entries).
  final List<String> suiteNewFailures;

  CycleLogEntry({
    required this.behaviorId,
    required this.kind,
    required this.runnerCommand,
    required this.exitCode,
    required this.capturedOutput,
    required this.sourceCriterion,
    required this.testPath,
    required this.timestamp,
    this.classification,
    this.refactorActions = const [],
    this.isNoOp = false,
    this.generationSteps,
    this.suiteBaselineFailures,
    this.suiteGuardFailures,
    this.suiteNewFailures = const [],
  }) : assert(
         kind != CycleEntryKind.red || classification != null,
         'Red entries must carry a failure classification.',
       );

  String toMarkdown() {
    final kindLabel = _kindLabel(kind);
    final buf = StringBuffer()
      ..writeln('## Cycle: $behaviorId ($kindLabel)')
      ..writeln()
      ..writeln('- behavior: $behaviorId')
      ..writeln('- kind: $kindLabel');
    if (classification != null) {
      buf.writeln('- classification: ${classification!.name}');
    }
    buf
      ..writeln('- criterion: $sourceCriterion')
      ..writeln('- test: $testPath')
      ..writeln('- command: `$runnerCommand`')
      ..writeln('- exit: $exitCode')
      ..writeln('- at: $timestamp');
    if (isNoOp) {
      buf.writeln('- no-op: true');
    }
    buf
      ..writeln('- output:')
      ..writeln('```')
      ..writeln(capturedOutput.trim())
      ..writeln('```');
    if (kind == CycleEntryKind.refactor && refactorActions.isNotEmpty) {
      buf.writeln('actions:');
      for (final action in refactorActions) {
        buf
          ..writeln('- action: ${action.name}')
          ..writeln('  command: `${action.command}`')
          ..writeln('  exit: ${action.exitCode}');
        if (action.filesChanged.isEmpty) {
          buf.writeln('  changed: (none)');
        } else {
          buf.writeln('  changed: ${action.filesChanged.join(', ')}');
        }
      }
    }

    if (kind == CycleEntryKind.green) {
      buf.writeln('- generation:');
      if (generationSteps == null) {
        buf.writeln('  (evidence missing)');
      } else if (generationSteps!.isEmpty) {
        buf.writeln('  (none)');
      } else {
        for (final step in generationSteps!) {
          buf.writeln('  - step: ${step.command}');
          buf.writeln('    exit: ${step.exitCode}');
          buf.writeln('    purpose: ${step.purpose}');
        }
      }
      final newFailures = suiteNewFailures.isEmpty
          ? '(none)'
          : suiteNewFailures.join(', ');
      final baselineFailures = suiteBaselineFailures ?? '(evidence missing)';
      final guardFailures = suiteGuardFailures ?? '(evidence missing)';
      buf.writeln(
        '- suite: baseline=$baselineFailures '
        'guard=$guardFailures new=$newFailures',
      );
    }

    buf.writeln();
    return buf.toString();
  }

  /// Map a [CycleEntryKind] to its lowercase contract label.
  ///
  /// Kept as a helper so the red/green/refactor labels stay in one place;
  /// the previous `kind == red ? 'red' : 'green'` ternary silently
  /// mislabelled refactor entries as green (spec 048 Decision 5).
  static String _kindLabel(CycleEntryKind kind) {
    switch (kind) {
      case CycleEntryKind.red:
        return 'red';
      case CycleEntryKind.green:
        return 'green';
      case CycleEntryKind.refactor:
        return 'refactor';
    }
  }

  @override
  String toString() =>
      'CycleLogEntry($behaviorId, $kind, exit=$exitCode, '
      'class=$classification, steps=${generationSteps?.length ?? 'missing'})';
}
