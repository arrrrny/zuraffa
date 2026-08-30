/// `CycleLogEntry` entity — one row of `tdd/cycle-log.md`.
///
/// Extended by spec 046-tdd-verify-red (T002): red entries carry the full
/// 8-field evidence contract — behavior id, source criterion, test path,
/// runner command, runner exit code, classification, captured failure
/// output, and timestamp (spec 046 FR-006).
library;

enum CycleEntryKind { red, green }

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
  final String testPath;

  /// ISO-8601 UTC timestamp of the run.
  final String timestamp;

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
  }) : assert(
         kind == CycleEntryKind.green || classification != null,
         'Red entries must carry a failure classification.',
       );

  String toMarkdown() {
    final kindLabel = kind == CycleEntryKind.red ? 'red' : 'green';
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
      ..writeln('- at: $timestamp')
      ..writeln('- output:')
      ..writeln('```')
      ..writeln(capturedOutput.trim())
      ..writeln('```')
      ..writeln();
    return buf.toString();
  }

  @override
  String toString() =>
      'CycleLogEntry($behaviorId, $kind, exit=$exitCode, '
      'class=$classification)';
}
