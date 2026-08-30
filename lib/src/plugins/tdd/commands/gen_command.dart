/// `zfa tdd gen <behavior-id>` — materializes a planned behavior into
/// exactly ONE test + ONE compilable subject (spec 044-test-tdd-generation,
/// FR-001..011).
///
/// The command:
///   1. Loads `specs/<feature>/tdd/test-list.md` and looks up the behavior
///      row by id. If the id is unknown or the row is malformed, exits
///      non-zero BEFORE any file is written (FR-002).
///   2. Computes the test path + subject path + runnable test name for the
///      behavior. Path convention: `test/tdd/<snake-id>_test.dart` and
///      `lib/tdd/<snake-id>_subject.dart`.
///   3. Delegates test file writing to [BehaviorTestWriter] and subject
///      file writing to [SubjectWriter].
///   4. Persists an [ArtifactRecord] via [ArtifactRegistry] (FR-007).
///   5. Prints a structured result with the six required fields (FR-005):
///      behavior_id, source_criterion, test_path, subject_path,
///      runnable_test_name, ownership.
///
/// Idempotent: a repeat `gen` for the same behavior is a no-op that returns
/// `Ownership.reused` for both artifacts (FR-006).
///
/// Ownership conflict: if a file exists on disk but the registry has no
/// record for it, exits non-zero WITHOUT modifying the file (FR-008).
///
/// `--dry-run`: plans the pair without writing anything (FR-009).
library;

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/artifact_registry.dart';
import '../services/behavior_test_writer.dart';
import '../services/subject_writer.dart';
import 'verify_red_command.dart' show zfaTddWorkingDirectory;
import '../tdd_plugin.dart';

class GenCommand extends Command<void> {
  GenCommand(this.plugin) {
    argParser.addFlag(
      'dry-run',
      abbr: 'n',
      help: 'Plan the test+subject pair without writing anything (FR-009).',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addOption(
      'feature',
      help:
          'Feature name (e.g. 044-test-tdd-generation). When set, only '
          'specs/<feature>/tdd/test-list.md is scanned for the behavior id. '
          'When omitted, all feature dirs are scanned and the first match '
          'wins (with a preference for the cwd-matching feature).',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'gen';

  @override
  String get description =>
      'Generate a failing test + compiling source stub for a behavior '
      '(spec 044-test-tdd-generation, FR-001..011).';

  @override
  String get invocation => 'zfa tdd gen <behavior-id> [--dry-run]';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      usageException('Behavior id is required: zfa tdd gen <behavior-id>');
    }
    final behaviorId = rest.first;
    final dryRun = argResults!['dry-run'] as bool;
    final featureFlag = argResults!['feature'] as String?;
    final cwd =
        Zone.current[zfaTddWorkingDirectory] as String? ??
        Directory.current.path;

    // Resolve the behavior. If --feature is set, only scan that one
    // feature's test-list. Otherwise, scan all features and prefer
    // `044-test-tdd-generation` (the feature this command lives under).
    final resolved = await _resolveBehavior(cwd, behaviorId, featureFlag);
    if (resolved == null) {
      stderr.writeln(
        'zfa tdd gen: unknown behavior id "$behaviorId". '
        'No matching row found in any specs/<feature>/tdd/test-list.md'
        '${featureFlag != null ? " for feature $featureFlag" : ""}.',
      );
      throw StateError('zfa tdd gen: unknown behavior id "$behaviorId"');
    }
    final (behavior, featureDir, featureName) = resolved;

    // Validate required fields up front (FR-002).
    final missingFields = _missingRequiredFields(behavior);
    if (missingFields.isNotEmpty) {
      stderr.writeln(
        'zfa tdd gen: behavior "$behaviorId" is missing required '
        'field(s): ${missingFields.join(', ')}. Refusing to write any '
        'file.',
      );
      throw StateError(
        'zfa tdd gen: missing required field(s): ${missingFields.join(', ')}',
      );
    }

    // Compute paths.
    final snakeId = _toSnakeCase(behavior.id);
    final testPath = '$cwd/test/tdd/${snakeId}_test.dart';
    final subjectPath = '$cwd/lib/tdd/${snakeId}_subject.dart';
    final runnableTestName =
        '$testPath::${behavior.id}::${behavior.description}';

    final registry = ArtifactRegistry(featureDir: featureDir);

    // Build the proposed record, then preflight ownership without changing
    // the registry. The record is appended only after both writes succeed.
    var record = ArtifactRecord(
      behaviorId: behavior.id,
      feature: featureName,
      sourceCriterion: behavior.sourceCriterion,
      testPath: testPath,
      subjectPath: subjectPath,
      runnableTestName: runnableTestName,
      testOwnership: dryRun ? Ownership.planned : Ownership.created,
      subjectOwnership: dryRun ? Ownership.planned : Ownership.created,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );

    try {
      record = await registry.preflight(record, dryRun: dryRun);
    } on OwnershipConflict catch (e) {
      stderr.writeln('zfa tdd gen: ownership conflict — $e');
      throw StateError('zfa tdd gen: ownership conflict — $e');
    }

    // Write a new pair transactionally from the command's perspective. Any
    // writer or registry failure removes artifacts created by this attempt.
    if (record.testOwnership != Ownership.reused && !dryRun) {
      try {
        final testWriter = const BehaviorTestWriter();
        await testWriter.write(
          behavior: behavior,
          testPath: testPath,
          subjectPath: subjectPath,
        );
        final subjectWriter = const SubjectWriter();
        await subjectWriter.write(behavior: behavior, subjectPath: subjectPath);
        record = await registry.append(record);
      } catch (error, stackTrace) {
        await _deleteIfCreated(testPath);
        await _deleteIfCreated(subjectPath);
        Error.throwWithStackTrace(error, stackTrace);
      }
    }

    // Print the structured result. Use `print` (not `stdout.writeln`) so
    // the CliRunner's runCapturing zone can capture it.
    print(
      'behavior_id: ${record.behaviorId}\n'
      'source_criterion: ${record.sourceCriterion}\n'
      'test_path: ${record.testPath}\n'
      'subject_path: ${record.subjectPath}\n'
      'runnable_test_name: ${record.runnableTestName}\n'
      'ownership: ${record.testOwnership.name}/${record.subjectOwnership.name}',
    );
  }

  Future<void> _deleteIfCreated(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Resolve a behavior id (e.g. `B-003` or `U1`) by scanning feature
  /// `test-list.md` files. If [featureFlag] is set, only that feature is
  /// scanned. Otherwise, all features are scanned and the first match in
  /// alphabetical order wins, with a preference for
  /// `044-test-tdd-generation` (the feature this command lives under).
  Future<(Behavior, String featureDir, String featureName)?> _resolveBehavior(
    String cwd,
    String behaviorId,
    String? featureFlag,
  ) async {
    final specsDir = Directory('$cwd/specs');
    if (!await specsDir.exists()) return null;

    if (featureFlag != null && featureFlag.isNotEmpty) {
      // Only scan the specified feature.
      final featureDir = '$cwd/specs/$featureFlag';
      final testListFile = File('$featureDir/tdd/test-list.md');
      if (await testListFile.exists()) {
        final raw = await testListFile.readAsString();
        final behavior = _parseBehaviorRow(raw, behaviorId, featureFlag);
        if (behavior != null) return (behavior, featureDir, featureFlag);
      }
      return null;
    }

    // No --feature given: scan all feature dirs and reject ambiguous IDs.
    final matches = <(Behavior, String featureDir, String featureName)>[];
    final dirs = <Directory>[];
    await for (final entity in specsDir.list()) {
      if (entity is Directory) dirs.add(entity);
    }
    dirs.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    for (final entity in dirs) {
      final featureName = p.basename(entity.path);
      final testListFile = File('${entity.path}/tdd/test-list.md');
      if (!await testListFile.exists()) continue;
      final raw = await testListFile.readAsString();
      final behavior = _parseBehaviorRow(raw, behaviorId, featureName);
      if (behavior != null) {
        matches.add((behavior, entity.path, featureName));
      }
    }
    if (matches.isEmpty) return null;
    if (matches.length > 1) {
      final features = matches.map((m) => m.$3).join(', ');
      stderr.writeln(
        'zfa tdd gen: ambiguous behavior id "$behaviorId" found in '
        'multiple features: $features. Use --feature to disambiguate.',
      );
      throw StateError(
        'zfa tdd gen: ambiguous behavior id "$behaviorId" in $features',
      );
    }
    return matches.first;
  }

  /// Parse a behavior row from a test-list.md file.
  Behavior? _parseBehaviorRow(String raw, String behaviorId, String feature) {
    for (final line in raw.split('\n')) {
      if (!line.trimLeft().startsWith('|')) continue;
      if (line.contains('---')) continue; // separator
      // Expected format:
      // | <id> | <description> | <source> | <kind> | <state> | <target> |
      // Don't filter empty cells — empty description is a valid (malformed)
      // input that we must surface as a missing-required-field error.
      final parts = line.split('|');
      // The first and last elements are empty (before/after the outer pipes).
      if (parts.length < 7) continue; // need 6 cells + 2 outer empties
      // Strip outer empties and leading/trailing whitespace from each cell.
      final cells = parts
          .sublist(1, parts.length - 1)
          .map((s) => s.trim())
          .toList();
      if (cells.length < 6) continue;
      final id = cells[0];
      if (id != behaviorId) continue;
      final description = cells[1];
      final sourceCriterion = cells[2];
      final kindStr = cells[3].toLowerCase();
      // target is in cells[5]; may be a test path (when the test-list
      // was generated by `zfa tdd plan`) or a function name. When it
      // looks like a path, default to a snake_case function name
      // derived from the behavior id.
      final cell5 = cells[5];
      final target =
          cell5.isEmpty ||
              cell5.contains('/') ||
              cell5.contains('::') ||
              cell5.contains(r'$')
          ? 'subject_${behaviorId.toLowerCase().replaceAll('-', '_')}'
          : cell5;
      final kind = kindStr.contains('acceptance')
          ? BehaviorKind.acceptance
          : kindStr.contains('unit')
          ? BehaviorKind.unit
          : throw StateError(
              'zfa tdd gen: invalid classification "$kindStr" '
              'for behavior $behaviorId. Expected "unit" or "acceptance".',
            );
      return Behavior(
        id: id,
        feature: feature,
        kind: kind,
        description: description,
        sourceCriterion: sourceCriterion,
        target: target,
      );
    }
    return null;
  }

  /// Validate the required fields (FR-002).
  List<String> _missingRequiredFields(Behavior b) {
    final missing = <String>[];
    if (b.id.isEmpty) missing.add('behavior id');
    if (b.description.isEmpty) missing.add('description');
    if (b.sourceCriterion.isEmpty) missing.add('source criterion');
    if (b.target.isEmpty) missing.add('target');
    return missing;
  }

  String _toSnakeCase(String s) {
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '-' || c == ' ' || c == '_') {
        out.write('_');
      } else if (c.toUpperCase() == c && c.toLowerCase() != c && i > 0) {
        out.write('_');
        out.write(c.toLowerCase());
      } else {
        out.write(c.toLowerCase());
      }
    }
    return out.toString();
  }
}
