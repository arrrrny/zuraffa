import 'dart:io';

import 'package:args/command_runner.dart';

import '../migration/migration_models.dart';
import '../migration/detectors/gql_detector.dart';
import '../migration/detectors/state_detector.dart';
import '../migration/detectors/di_detector.dart';
import '../migration/fixers/state_fixer.dart';
import '../migration/fixers/gql_fixer.dart';

/// `zfa migrate [state|gql|di]` -- migrates v5 artifacts to v6 equivalents.
class MigrateCommand extends Command<void> {
  @override
  final String name = 'migrate';

  @override
  final String description =
      'Migrate v5 artifacts to v6 equivalents (state, gql, di).';

  MigrateCommand() {
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview changes without writing files',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show detailed output',
    );
  }

  @override
  Future<void> run() async {
    final dryRun = argResults!['dry-run'] == true;
    final verbose = argResults!['verbose'] == true;
    final subcommand = argResults!.rest.isEmpty ? null : argResults!.rest.first;

    if (subcommand == null || subcommand == 'help') {
      _printUsage();
      return;
    }

    final projectDir = Directory.current.path;

    switch (subcommand) {
      case 'state':
        await _migrateState(projectDir, dryRun, verbose);
      case 'gql':
        await _migrateGql(projectDir, dryRun, verbose);
      case 'di':
        await _migrateDi(projectDir, dryRun, verbose);
      default:
        print('Unknown migration target: $subcommand');
        print('Available: state, gql, di');
        print('');
        _printUsage();
    }
  }

  Future<void> _migrateState(
    String projectDir,
    bool dryRun,
    bool verbose,
  ) async {
    print('Scanning for v5 state files...');

    final detector = StateDetector();
    final result = await detector.detect(projectDir);

    if (!result.hasFindings) {
      print('No v5 mixed state files found. Nothing to migrate.');
      return;
    }

    print('Found ${result.findings.length} state file(s) to migrate:');
    for (final f in result.findings) {
      print('  - ${f.filePath}');
    }
    print('');

    if (dryRun) {
      print('Dry-run mode -- no files will be written.');
      print('');
    }

    final migrator = StateMigrator();
    final migrationResult = await migrator.migrate(
      findings: result.findings,
      projectDir: projectDir,
      dryRun: dryRun,
    );

    _printMigrationResult(migrationResult, dryRun, verbose);
  }

  Future<void> _migrateGql(String projectDir, bool dryRun, bool verbose) async {
    print('Scanning for v5 GraphQL const-string documents...');

    final detector = GqlConstStringDetector();
    final result = await detector.detect(projectDir);

    if (!result.hasFindings) {
      print('No v5 GraphQL const-string documents found. Nothing to migrate.');
      return;
    }

    print('Found ${result.findings.length} document(s) to migrate:');
    for (final f in result.findings) {
      print('  - ${f.filePath}:${f.line}');
    }
    print('');

    if (dryRun) {
      print('Dry-run mode -- no files will be written.');
      print('');
    }

    final migrator = GqlMigrator();
    final migrationResult = await migrator.migrate(
      findings: result.findings,
      projectDir: projectDir,
      dryRun: dryRun,
    );

    _printMigrationResult(migrationResult, dryRun, verbose);
  }

  Future<void> _migrateDi(String projectDir, bool dryRun, bool verbose) async {
    print('Scanning for manual get_it DI registrations...');

    final detector = ManualDiDetector();
    final result = await detector.detect(projectDir);

    if (!result.hasFindings) {
      print('No manual get_it registrations found. Nothing to migrate.');
      return;
    }

    print('Found ${result.findings.length} registration(s):');
    for (final f in result.findings) {
      print('  ${f.filePath}:${f.line} -- ${f.message}');
    }
    print('');

    print('DI migration is currently detection-only.');
    print('Manual steps required:');
    print('  1. Add @Datasource annotation to datasource classes');
    print('  2. Add @Repository annotation to repository implementations');
    print('  3. Remove manual getIt.registerXXX calls');
    print('  4. Use constructor injection in consumers');
    if (dryRun) {
      print('');
      print('Dry-run mode -- no files modified.');
    }
  }

  void _printMigrationResult(
    MigrationResult result,
    bool dryRun,
    bool verbose,
  ) {
    if (result.actions.isEmpty) {
      print('No actions taken.');
      return;
    }

    print('Migration result:');
    if (result.filesCreated > 0) {
      print('  Created: ${result.filesCreated} file(s)');
    }
    if (result.filesModified > 0) {
      print('  Modified: ${result.filesModified} file(s)');
    }
    if (result.filesDeleted > 0) {
      print('  Deleted: ${result.filesDeleted} file(s)');
    }
    print('');

    if (verbose || dryRun) {
      for (final action in result.actions) {
        final tag = action.action == 'created'
            ? '[created]'
            : action.action == 'modified'
            ? '[modified]'
            : '[deleted]';
        print('  $tag ${action.filePath}');
        print('    ${action.description}');
      }
      print('');
    }

    if (dryRun) {
      print('Dry-run complete. Re-run without --dry-run to apply.');
    } else {
      print(
        'Migration complete. Review generated files and update references.',
      );
      print('Run `dart analyze` to verify no regressions.');
    }
  }

  void _printUsage() {
    print('USAGE: zfa migrate <target> [options]');
    print('');
    print('TARGETS:');
    print(
      '  state   Migrate v5 mixed .state.dart files to v6 DomainState + ViewState',
    );
    print(
      '  gql     Migrate v5 const-string GraphQL documents to .graphql files',
    );
    print(
      '  di      Detect manual get_it registrations (detection-only, manual fix)',
    );
    print('');
    print('OPTIONS:');
    print('  --dry-run   Preview changes without writing files');
    print('  -v, --verbose  Show detailed output');
    print('');
    print('EXAMPLES:');
    print('  zfa migrate state              # Migrate all mixed state files');
    print('  zfa migrate state --dry-run    # Preview state migration');
    print('  zfa migrate gql --verbose      # Migrate GQL with details');
    print('  zfa migrate di                 # Detect manual DI patterns');
  }
}
