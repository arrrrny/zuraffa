import 'package:meta/meta.dart';

/// A single finding from a v5 pattern scan.
@immutable
class MigrationFinding {
  /// Human-readable description of the finding.
  final String message;

  /// Absolute or project-relative file path.
  final String filePath;

  /// 1-based line number in [filePath]. Zero if not applicable.
  final int line;

  /// Machine-readable rule ID, e.g. `v5_gql_const_string`.
  final String ruleId;

  /// Severity of this finding.
  final MigrationSeverity severity;

  /// Suggested fix description. May be `null` when no automatic fix
  /// is available.
  final String? suggestion;

  const MigrationFinding({
    required this.message,
    required this.filePath,
    required this.line,
    required this.ruleId,
    required this.severity,
    this.suggestion,
  });

  @override
  String toString() => '[$severity] $filePath:$line $ruleId: $message';
}

/// Severity levels for migration findings.
enum MigrationSeverity {
  /// Purely informational, no action required.
  info,

  /// Recommended migration, code will still compile.
  warning,

  /// Breaking change that must be addressed.
  error,
}

/// Result of running a single migration detector.
@immutable
class DetectorResult {
  final String detectorId;
  final List<MigrationFinding> findings;

  const DetectorResult({required this.detectorId, required this.findings});

  bool get hasFindings => findings.isNotEmpty;

  int get errorCount =>
      findings.where((f) => f.severity == MigrationSeverity.error).length;
  int get warningCount =>
      findings.where((f) => f.severity == MigrationSeverity.warning).length;
  int get infoCount =>
      findings.where((f) => f.severity == MigrationSeverity.info).length;
}

/// A migration action that was applied (or would be applied in dry-run).
@immutable
class MigrationAction {
  /// Human-readable description of what the action does.
  final String description;

  /// The file being modified or created.
  final String filePath;

  /// `created`, `modified`, or `deleted`.
  final String action;

  /// The new file content (for `created`/`modified`), or null.
  final String? newContent;

  /// The original content before modification, or null.
  final String? originalContent;

  const MigrationAction({
    required this.description,
    required this.filePath,
    required this.action,
    this.newContent,
    this.originalContent,
  });
}

/// Result of running a migration fixer.
@immutable
class MigrationResult {
  final String migratorId;
  final List<MigrationAction> actions;
  final List<MigrationFinding> remaining;

  const MigrationResult({
    required this.migratorId,
    required this.actions,
    this.remaining = const [],
  });

  int get filesCreated => actions.where((a) => a.action == 'created').length;
  int get filesModified => actions.where((a) => a.action == 'modified').length;
  int get filesDeleted => actions.where((a) => a.action == 'deleted').length;
}

/// Aggregated report for `zfa doctor` or `zfa migrate`.
@immutable
class MigrationReport {
  final List<DetectorResult> detectorResults;
  final List<MigrationResult> migrationResults;

  const MigrationReport({
    this.detectorResults = const [],
    this.migrationResults = const [],
  });

  List<MigrationFinding> get allFindings =>
      detectorResults.expand((d) => d.findings).toList();

  List<MigrationAction> get allActions =>
      migrationResults.expand((m) => m.actions).toList();

  int get totalErrors =>
      allFindings.where((f) => f.severity == MigrationSeverity.error).length;
  int get totalWarnings =>
      allFindings.where((f) => f.severity == MigrationSeverity.warning).length;
  int get totalInfo =>
      allFindings.where((f) => f.severity == MigrationSeverity.info).length;

  bool get hasIssues => totalErrors > 0 || totalWarnings > 0;

  bool get isClean => !hasIssues;
}
