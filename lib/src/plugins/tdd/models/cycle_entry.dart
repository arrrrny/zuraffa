/// `CycleLogEntry` entity — one row of `tdd/cycle-log.md`.
library;

enum CycleEntryKind { red, green }

enum FailureClass {
  assertionFailure,
  compileError,
  loadError,
  unexpectedGreen,
}

class CycleLogEntry {
  final String behaviorId;
  final CycleEntryKind kind;
  final String runnerCommand;
  final int exitCode;
  final String capturedOutput;
  final FailureClass? classification;

  CycleLogEntry({
    required this.behaviorId,
    required this.kind,
    required this.runnerCommand,
    required this.exitCode,
    required this.capturedOutput,
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
      ..writeln('- command: `$runnerCommand`')
      ..writeln('- exit: $exitCode')
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
