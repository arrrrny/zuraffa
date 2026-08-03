import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';

import '../migration/migration.dart';
import '../migration/migration_models.dart';
import '../migration/detectors/gql_detector.dart';
import '../migration/detectors/state_detector.dart';
import '../migration/detectors/di_detector.dart';
import '../migration/detectors/controlled_widget_detector.dart';
import '../migration/detectors/dependency_overrides_detector.dart';
import '../migration/fixers/state_fixer.dart';
import '../migration/fixers/gql_fixer.dart';
import '../version.dart';

class DoctorCommand extends Command<void> {
  @override
  final String name = 'doctor';

  @override
  final String description = 'Show information about the installed tooling and v5 migration readiness.';

  static const _timeout = Duration(seconds: 10);

  DoctorCommand() {
    argParser.addFlag(
      'fix',
      negatable: false,
      help: 'Automatically fix detected v5 patterns where possible',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Show what would change without writing files (implies --fix)',
    );
    argParser.addFlag(
      'migration-only',
      negatable: false,
      help: 'Only run v5 migration checks, skip tooling checks',
    );
  }

  void _print(String message) {
    print(message);
  }

  @override
  Future<void> run() async {
    final shouldFix = argResults!['fix'] == true || argResults!['dry-run'] == true;
    final dryRun = argResults!['dry-run'] == true;
    final migrationOnly = argResults!['migration-only'] == true;

    if (!migrationOnly) {
      await _runToolingChecks();
    }

    _print('');
    await _runMigrationChecks(shouldFix: shouldFix, dryRun: dryRun);
  }

  Future<void> _runToolingChecks() async {
    _print('Zuraffa Doctor');
    _print('');
    _print('Zuraffa CLI: v$version');

    try {
      final dartResult = await Process.run('dart', ['--version']).timeout(_timeout);
      final dartOutput = dartResult.stdout.toString().trim().isNotEmpty
          ? dartResult.stdout.toString().trim()
          : dartResult.stderr.toString().trim();
      _print('Dart: $dartOutput');
    } on TimeoutException {
      _print('Dart: Timeout');
    } catch (e) {
      _print('Dart: Not found');
    }

    try {
      final flutterResult = await Process.run('flutter', ['--version']).timeout(_timeout);
      if (flutterResult.exitCode == 0) {
        final flutterOutput = flutterResult.stderr.toString().split('\n').first.trim();
        if (flutterOutput.isEmpty) {
          _print('Flutter: Installed');
        } else {
          _print('Flutter: $flutterOutput');
        }
      } else {
        _print('Flutter: Not found (exit code ${flutterResult.exitCode})');
      }
    } on TimeoutException {
      _print('Flutter: Timeout (this is fine if you are only using Dart)');
    } catch (e) {
      _print('Flutter: Not found (this is fine if you are only using Dart)');
    }

    _print('');

    final configFile = File('.zfa.json');
    if (configFile.existsSync()) {
      _print('Configuration: Found .zfa.json');
    } else {
      _print('Configuration: No .zfa.json found (run "zfa config init" to create one)');
    }

    final pubspecFile = File('pubspec.yaml');
    if (pubspecFile.existsSync()) {
      _print('Project: Found pubspec.yaml');

      try {
        final content = await pubspecFile.readAsString();
        if (content.contains('zuraffa:')) {
          _print('Dependencies: Zuraffa package found');
        } else {
          _print('Dependencies: Zuraffa package not found in pubspec.yaml');
        }

        if (content.contains('zorphy_annotation:')) {
          _print('              zorphy_annotation found');
        } else {
          _print('              zorphy_annotation not found - required for entity generation');
          _print('                 Add: dart pub add zorphy_annotation');
        }
      } catch (e) {
        _print('Dependencies: Could not read pubspec.yaml');
      }
    } else {
      _print('Project: No pubspec.yaml found');
    }

    _print('');

    try {
      final zorphyResult = await Process.run('dart', ['pub', 'global', 'list']).timeout(_timeout);
      final output = zorphyResult.stdout.toString();
      if (output.contains('zorphy')) {
        final match = RegExp(r'zorphy\s+(\S+)').firstMatch(output);
        final zorphyVersion = match?.group(1) ?? 'unknown';
        _print('zorphy CLI: v$zorphyVersion (globally installed)');
      } else {
        _print('zorphy CLI: Not installed globally (optional)');
        _print('             zfa entity commands work without it (bundled)');
        _print('             For standalone use: dart pub global activate zorphy');
      }
    } on TimeoutException {
      _print('zorphy CLI: Timeout checking global packages');
    } catch (e) {
      _print('zorphy CLI: Could not check: $e');
    }

    _print('');
    await _checkDeadCode();
  }

  Future<void> _checkDeadCode() async {
    _print('Dead Code Analysis: Running dart analyze...');

    final entitiesDir = Directory('lib/src/domain/entities');
    int entityCount = 0;
    if (await entitiesDir.exists()) {
      entityCount = await entitiesDir.list().where((e) => e is Directory).length;
    }
    final timeout = Duration(seconds: (entityCount * 5 + 60).clamp(60, 120));

    try {
      final result = await Process.run('dart', ['analyze']).timeout(timeout);
      final output = result.stdout.toString();

      if (output.contains('Dead code') || output.contains('dead_code')) {
        _print('Dead Code Analysis: Found dead code issues');

        final lines = output.split('\n');
        final deadCodeLines = lines
            .where((line) => line.contains('Dead code') || line.contains('dead_code'))
            .take(5)
            .toList();

        for (final line in deadCodeLines) {
          _print('  $line');
        }

        if (deadCodeLines.length < lines.where((l) => l.contains('dead_code')).length) {
          _print('  ... and more.');
        }
      } else {
        _print('Dead Code Analysis: No dead code found');
      }
    } on TimeoutException {
      _print('Dead Code Analysis: Timeout (skipped)');
    } catch (e) {
      _print('Dead Code Analysis: Failed to run analysis: $e');
    }
  }

  Future<void> _runMigrationChecks({
    required bool shouldFix,
    required bool dryRun,
  }) async {
    _print('v5 Migration Readiness');
    _print('=======================');

    final projectDir = Directory.current.path;
    final detectors = <MigrationDetector>[
      DependencyOverridesDetector(),
      GqlConstStringDetector(),
      StateDetector(),
      ManualDiDetector(),
      ControlledWidgetDetector(),
    ];

    var report = MigrationReport();
    for (final detector in detectors) {
      final result = await detector.detect(projectDir);
      report = MigrationReport(
        detectorResults: [...report.detectorResults, result],
        migrationResults: report.migrationResults,
      );
    }

    // Print results grouped by detector
    for (final detResult in report.detectorResults) {
      final detector = detectors.firstWhere((d) => d.detectorId == detResult.detectorId);
      if (!detResult.hasFindings) {
        _print('  [PASS] ${detector.displayName}');
        continue;
      }

      _print('  [${_severityTag(detResult)}] ${detector.displayName}');
      for (final finding in detResult.findings.take(5)) {
        _print('    ${finding.filePath}:${finding.line} - ${finding.message}');
        if (finding.suggestion != null) {
          _print('      fix: ${finding.suggestion}');
        }
      }
      if (detResult.findings.length > 5) {
        _print('    ... and ${detResult.findings.length - 5} more');
      }
    }

    _print('');
    _print('Summary: ${report.totalErrors} error(s), ${report.totalWarnings} warning(s), ${report.totalInfo} info');

    if (report.isClean) {
      _print('');
      _print('This project appears to be v6-ready.');
      return;
    }

    if (!shouldFix) {
      _print('');
      _print('Run `zfa doctor --fix` to apply automatic fixes where possible.');
      _print('Run `zfa doctor --dry-run` to preview fixes without writing.');
      _print('Run `zfa migrate <state|gql|di>` for targeted migrations.');
    } else {
      _print('');
      if (dryRun) {
        _print('Applying fixes (dry-run)...');
      } else {
        _print('Applying fixes...');
      }

      // Fix state migrations
      final stateFindings = report.allFindings.where((f) => f.ruleId == 'v5_mixed_state').toList();
      if (stateFindings.isNotEmpty) {
        final migrator = StateMigrator();
        final result = await migrator.migrate(
          findings: stateFindings,
          projectDir: projectDir,
          dryRun: dryRun,
        );
        _print('  State migration: ${result.filesCreated} created, ${result.filesModified} modified');
      }

      // Fix gql migrations
      final gqlFindings = report.allFindings.where((f) => f.ruleId == 'v5_gql_const_string').toList();
      if (gqlFindings.isNotEmpty) {
        final migrator = GqlMigrator();
        final result = await migrator.migrate(
          findings: gqlFindings,
          projectDir: projectDir,
          dryRun: dryRun,
        );
        _print('  GQL migration: ${result.filesCreated} created, ${result.filesModified} modified');
      }

      if (dryRun) {
        _print('');
        _print('Dry-run complete. Re-run without --dry-run to apply.');
      } else {
        _print('');
        _print('Fixes applied. Run `dart analyze` to verify.');
      }
    }
  }

  String _severityTag(DetectorResult result) {
    if (result.errorCount > 0) return 'FAIL';
    if (result.warningCount > 0) return 'WARN';
    return 'INFO';
  }
}
