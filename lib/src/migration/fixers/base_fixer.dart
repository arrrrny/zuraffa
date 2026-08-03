import '../migration_models.dart';

/// Base class for migration fixers.
abstract class MigrationFixer {
  /// Machine-readable ID, should match the detector ID it handles.
  String get migratorId;

  /// Human-readable name.
  String get displayName;

  /// Run the migration.
  Future<MigrationResult> migrate({
    required List<MigrationFinding> findings,
    required String projectDir,
    bool dryRun = false,
  });
}
