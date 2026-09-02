/// `zfa tdd migrate-paths` — the bug #827 migration surface: moves a
/// feature's recorded TDD artifacts from the legacy flat layout
/// (`test/tdd/<id>_test.dart`, `lib/tdd/<id>_subject.dart`) to the
/// per-feature namespaced layout (`test/tdd/<feature-slug>/<id>_test.dart`,
/// `lib/tdd/<feature-slug>/<id>_subject.dart`) and rewrites the registry
/// records (test_path, subject_path, runnable_test_name) to match.
///
/// Why: gen namespaces artifacts by feature-slug (bug #827) so two features
/// planning the same behavior id never collide on one flat file. Projects
/// generated before the fix carry flat paths in their registries; re-gen of
/// such a behavior reports an ownership conflict naming this command. The
/// migration is:
///
/// - **Registry-driven**: only recorded artifacts move. An unrecorded flat
///   file is nobody's contract — the registry is the source of truth
///   (bug #720) — so it is left untouched.
/// - **Pair-atomic**: a record's test and subject move together. If either
///   move fails, the other is rolled back so the pair is never split.
/// - **Ownership-preserving**: a move onto an existing namespaced target is
///   REFUSED (reported, counted, exit 1) — the guardrail that refuses to
///   overwrite non-owned content (044 FR-008) applies to the migration
///   itself. Nothing is partially moved.
/// - **Fail-honest**: a record whose flat file is missing is reported and
///   left unchanged (a silent rewrite would trade a broken record for a
///   differently-broken one); any refusal or missing artifact exits non-zero.
/// - **Idempotent**: already-namespaced records are untouched and re-runs
///   migrate zero records.
/// - **Opt-in**: a flat project that never runs this command keeps working —
///   `dart test`/`flutter test` discover everything under `test/` regardless
///   of layout, and every registry-driven command (verify-red/make/wire/
///   func/compose/refactor) follows the recorded paths.
///
/// The machine contract is the summary line
/// `migrate-paths: migrated=<n> refused=<r> missing=<m> feature=<f|all>`
/// as the final stdout line; `--dry-run` reports the planned moves and
/// writes nothing.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/artifact_registry.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

class MigratePathsCommand extends Command<void> {
  MigratePathsCommand(this.plugin) {
    argParser.addFlag(
      'dry-run',
      abbr: 'n',
      help: 'Report the planned moves without touching any file.',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addOption(
      'feature',
      help:
          'Feature name (e.g. 044-test-tdd-generation). Restricts the '
          'migration to specs/<feature>/tdd/artifacts.json. When omitted, '
          'every feature registry is migrated.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and lib/. When omitted, '
          'the current working directory is used. Tests pass the temp '
          'fixture root here instead of mutating Directory.current.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'migrate-paths';

  @override
  String get description =>
      'Move recorded TDD artifacts from the legacy flat layout '
      '(test/tdd/<id>_test.dart) to the per-feature namespaced layout '
      '(test/tdd/<feature-slug>/<id>_test.dart) and rewrite the registry '
      'records (bug #827).';

  @override
  String get invocation =>
      'zfa tdd migrate-paths [--feature <name>] [--project <path>] [--dry-run]';

  @override
  Future<void> run() async {
    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final featureFlag = argResults?['feature'] as String?;
    final projectFlag = argResults?['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.normalize(p.absolute(projectFlag))
        : ProjectRoot.find();

    var migrated = 0;
    var refused = 0;
    var missing = 0;
    var sawAnyRegistry = false;

    for (final entry in _scanRegistries(cwd, featureFlag)) {
      sawAnyRegistry = true;
      final registry = ArtifactRegistry(featureDir: entry.featureDir);
      final records = await registry.loadAll();
      if (records.isEmpty) continue;

      final updated = <ArtifactRecord>[];
      var registryDirty = false;

      for (final record in records) {
        final plan = _plan(record, cwd, entry.featureName);

        // Already namespaced (or a custom layout this command does not
        // own): leave the record exactly as it is.
        if (plan == null) {
          updated.add(record);
          continue;
        }

        final testFrom = _resolve(cwd, record.testPath);
        final subjectFrom = _resolve(cwd, record.subjectPath);
        final testTo = _resolve(cwd, plan.testPath);
        final subjectTo = _resolve(cwd, plan.subjectPath);

        // Fail-honest: a missing flat artifact cannot be verified-and-moved,
        // and silently rewriting the record would just relocate the break.
        if (!File(testFrom).existsSync() || !File(subjectFrom).existsSync()) {
          missing++;
          final missingHalf = File(testFrom).existsSync()
              ? 'subject "$record.subjectPath"'
              : 'test "$record.testPath"';
          print(
            'zfa tdd migrate-paths: MISSING for behavior '
            '"${record.behaviorId}" in ${entry.featureName}: the recorded '
            'flat $missingHalf does not exist on disk. The record is left '
            'unchanged — restore or remove the artifact first.',
          );
          updated.add(record);
          continue;
        }

        // Ownership guardrail: never overwrite non-owned content at the
        // target. The pair moves together or not at all.
        final targetTaken =
            File(testTo).existsSync() || File(subjectTo).existsSync();
        if (targetTaken) {
          refused++;
          print(
            'zfa tdd migrate-paths: REFUSED for behavior '
            '"${record.behaviorId}" in ${entry.featureName}: the namespaced '
            'target already exists '
            '(test "${plan.testPath}" / subject "${plan.subjectPath}"). '
            'Resolve the target first — the migration never overwrites.',
          );
          updated.add(record);
          continue;
        }

        print(
          'zfa tdd migrate-paths: ${dryRun ? 'would move' : 'moving'} '
          '${record.behaviorId} in ${entry.featureName}: '
          '${_rel(cwd, testFrom)} -> ${_rel(cwd, testTo)}, '
          '${_rel(cwd, subjectFrom)} -> ${_rel(cwd, subjectTo)}',
        );
        if (!dryRun) {
          try {
            File(testTo).parent.createSync(recursive: true);
            File(subjectTo).parent.createSync(recursive: true);
            File(testFrom).renameSync(testTo);
            try {
              File(subjectFrom).renameSync(subjectTo);
            } catch (_) {
              // Roll the pair back together: never leave it split.
              File(testTo).renameSync(testFrom);
              rethrow;
            }
          } on FileSystemException catch (e) {
            refused++;
            print(
              'zfa tdd migrate-paths: REFUSED for behavior '
              '"${record.behaviorId}" in ${entry.featureName}: the move '
              'failed on the filesystem: ${e.message}',
            );
            updated.add(record);
            continue;
          }
          _cleanupEmptyLegacyDirs(cwd, plan);
        }
        migrated++;
        registryDirty = true;
        updated.add(plan.record);
      }

      if (registryDirty && !dryRun) {
        await _writeRecords(registry, updated);
      }
    }

    if (!sawAnyRegistry) {
      print(
        'zfa tdd migrate-paths: no feature registry found under '
        '${_rel(cwd, p.join(cwd, 'specs'))} '
        '(expected specs/<feature>/tdd/artifacts.json). Nothing to migrate.',
      );
    }
    final featureLabel = (featureFlag != null && featureFlag.isNotEmpty)
        ? featureFlag
        : 'all';
    if (dryRun) {
      print('zfa tdd migrate-paths: dry-run — no changes were written.');
    }
    print(
      'migrate-paths: migrated=$migrated refused=$refused missing=$missing '
      'feature=$featureLabel',
    );
    exitCode = (refused > 0 || missing > 0) ? 1 : 0;
  }

  // -------------------------------------------------------------------
  // Planning + filesystem helpers.
  // -------------------------------------------------------------------

  /// Whether [record] carries a LEGACY flat artifact path this command
  /// owns: `<root>/test/tdd/<file>` + `<root>/lib/tdd/<file>` (absolute or
  /// root-relative). Returns the namespaced plan, or null when the record
  /// is already namespaced (or lives at a custom path this command never
  /// touches).
  _MigrationPlan? _plan(ArtifactRecord record, String cwd, String feature) {
    final testRel = _rel(cwd, _resolve(cwd, record.testPath));
    final subjectRel = _rel(cwd, _resolve(cwd, record.subjectPath));

    final testSegments = _segments(testRel);
    final subjectSegments = _segments(subjectRel);

    // Legacy shape: test/tdd/<file> — exactly three segments.
    final testIsFlat = _isFlat(testSegments, 'test');
    final subjectIsFlat = _isFlat(subjectSegments, 'lib');
    if (!testIsFlat && !subjectIsFlat) return null;

    // A record can only be half-flat if it was hand-edited into an
    // inconsistent state; migrate the flat halves that exist (the common
    // case is both-flat or both-namespaced — both-namespaced yields null
    // above). Namespaced halves pass through unchanged.
    String namespacedTestPath(String file) => 'test/tdd/$feature/$file';
    String namespacedSubjectPath(String file) => 'lib/tdd/$feature/$file';

    final testFile = p.basename(testRel);
    final subjectFile = p.basename(subjectRel);

    final newTestRel = testIsFlat ? namespacedTestPath(testFile) : testRel;
    final newSubjectRel = subjectIsFlat
        ? namespacedSubjectPath(subjectFile)
        : subjectRel;

    return _MigrationPlan(
      testPath: newTestRel,
      subjectPath: newSubjectRel,
      record: _withPaths(record, newTestRel, newSubjectRel),
    );
  }

  bool _isFlat(List<String> segments, String root) =>
      segments.length == 3 && segments[0] == root && segments[1] == 'tdd';

  /// The runnable name is `<testPath>::<id>::<description>` — rebuild it
  /// with the namespaced test path, preserving the recorded description
  /// (mirrors make's `_descriptionFor` split).
  ArtifactRecord _withPaths(
    ArtifactRecord record,
    String testPath,
    String subjectPath,
  ) {
    final parts = record.runnableTestName.split('::');
    final description = parts.length >= 3 ? parts[2] : record.behaviorId;
    return ArtifactRecord(
      behaviorId: record.behaviorId,
      feature: record.feature,
      sourceCriterion: record.sourceCriterion,
      testPath: testPath,
      subjectPath: subjectPath,
      runnableTestName: '$testPath::${record.behaviorId}::$description',
      testOwnership: record.testOwnership,
      subjectOwnership: record.subjectOwnership,
      createdAt: record.createdAt,
    );
  }

  /// Normalize a recorded path to an absolute one (records may be absolute
  /// — gen's default — or project-relative).
  String _resolve(String cwd, String recorded) => p.isAbsolute(recorded)
      ? p.normalize(recorded)
      : p.normalize(p.join(cwd, recorded));

  /// The path relative to the project root, POSIX separators (display +
  /// registry-rewrite form).
  String _rel(String cwd, String absolute) =>
      p.relative(absolute, from: cwd).replaceAll(r'\', '/');

  List<String> _segments(String posixRel) =>
      posixRel.split('/').where((s) => s.isNotEmpty && s != '.').toList();

  /// Remove the legacy flat directories when the move left them empty, so
  /// a fully-migrated project does not keep ghost dirs around. Best-effort:
  /// a non-empty dir (unrecorded flat files) is intentionally kept.
  void _cleanupEmptyLegacyDirs(String cwd, _MigrationPlan plan) {
    for (final rel in const ['test/tdd', 'lib/tdd']) {
      final dir = Directory(p.join(cwd, rel));
      try {
        if (dir.existsSync() && dir.listSync().isEmpty) {
          dir.deleteSync();
        }
      } on FileSystemException {
        // Best-effort only; the migration outcome is unaffected.
      }
    }
  }

  Future<void> _writeRecords(
    ArtifactRegistry registry,
    List<ArtifactRecord> records,
  ) async {
    final file = File(registry.registryPath);
    await file.parent.create(recursive: true);
    // Same compact encoding the registry itself writes (the registry stays
    // the reader/writer of record; this only rewrites its file once).
    final raw = jsonEncode({
      'feature': p.basename(registry.featureDir),
      'records': records.map((r) => r.toJson()).toList(),
    });
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(raw);
    await tmp.rename(file.path);
  }

  List<_RegistryEntry> _scanRegistries(String cwd, String? featureFlag) {
    if (featureFlag != null && featureFlag.isNotEmpty) {
      final featureDir = p.join(cwd, 'specs', featureFlag);
      return [_RegistryEntry(featureFlag, featureDir)];
    }
    final specsDir = Directory(p.join(cwd, 'specs'));
    if (!specsDir.existsSync()) return const [];
    final dirs = specsDir.listSync().whereType<Directory>().toList()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    final entries = <_RegistryEntry>[];
    for (final dir in dirs) {
      if (File(p.join(dir.path, 'tdd', 'artifacts.json')).existsSync()) {
        entries.add(_RegistryEntry(p.basename(dir.path), dir.path));
      }
    }
    return entries;
  }
}

class _RegistryEntry {
  const _RegistryEntry(this.featureName, this.featureDir);

  final String featureName;
  final String featureDir;
}

class _MigrationPlan {
  const _MigrationPlan({
    required this.testPath,
    required this.subjectPath,
    required this.record,
  });

  final String testPath;
  final String subjectPath;
  final ArtifactRecord record;
}
