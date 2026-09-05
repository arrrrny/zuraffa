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
///   move fails — or the moved test's relative subject import / the cycle
///   log's recorded paths cannot be rewritten — everything rolls back so
///   the pair is never split and never left un-compilable.
/// - **Ownership-preserving**: a move onto an existing namespaced target is
///   REFUSED (reported, counted, exit 1) — the guardrail that refuses to
///   overwrite non-owned content (044 FR-008) applies to the migration
///   itself. Nothing is partially moved.
/// - **Fail-honest**: a record whose flat file is missing is reported and
///   left unchanged (a silent rewrite would trade a broken record for a
///   differently-broken one); any refusal or missing artifact exits non-zero.
/// - **Idempotent**: already-namespaced records are untouched and re-runs
///   migrate zero records.
/// - **Package-URI aware + self-checked (issue #912 defect 4)**: the moved
///   test's subject reference is rewritten in BOTH forms — the relative
///   path AND the `package:<host>/tdd/...` URI — composed tests get every
///   moved sibling subject rewritten, and a final self-check verifies the
///   touched tests' relative/self-package imports RESOLVE ON DISK before
///   success may be declared. A reference that cannot be made resolvable
///   rolls the pair back and is refused (exit 1) — never `migrated=N`
///   success on an unloadable suite.
/// - **Repairs already-migrated-but-broken pairs (issue #912)**: a
///   namespaced record whose test still references the legacy flat
///   subject location (a pre-#912 migration's residue) is repaired on
///   re-run and counted under `migrated=`.
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
import '../services/import_resolution.dart';
import '../services/verdict_emitter.dart';
import '../models/verdict_envelope.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

class MigratePathsCommand extends Command<void> {
  MigratePathsCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #969).',
      negatable: false,
    );
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

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

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
  Future<void> run() => runWithVerdictEnvelope(this, _verdict, _run);

  Future<void> _run() async {
    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final featureFlag = argResults?['feature'] as String?;
    final projectFlag = argResults?['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.normalize(p.absolute(projectFlag))
        : ProjectRoot.find(anchorDir: 'specs');

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
      // Issue #912 defect 4: the pairs moved by THIS run, in registry
      // order. The post-move pass finishes what the per-pair pass started
      // (cross-pair references in composed tests), then self-checks every
      // moved test's imports before success may be declared.
      final moves = <_MovedPair>[];
      final movedTestToPaths = <String>{};

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
            // Review fix: the moved test's relative subject import and the
            // cycle log's recorded paths still name the FLAT layout.
            // `../../lib/tdd/<id>_subject.dart` from inside
            // `test/tdd/<feature>/` resolves to `test/lib/tdd/...` — a
            // compile error that reds the whole migrated suite (issue
            // #827 requirement 4: the multi-feature green suite is the
            // norm). Rewrite both; a pair whose references cannot be
            // rewritten is a pair that no longer compiles, so the move
            // rolls back and refuses rather than shipping a broken suite.
            //
            // Issue #912 defect 4: the rewrite now covers BOTH reference
            // forms (relative AND the self-package URI) and VERIFIES the
            // subject reference resolves before moving on; the cycle-log
            // rewrite + the cross-pair/self-check pass run AFTER the whole
            // registry's pairs moved (below), so composed tests and
            // refused pairs are handled without split-brain state.
            try {
              _rewriteMovedTestReferences(
                cwd: cwd,
                testFrom: testFrom,
                testTo: testTo,
                subjectFrom: subjectFrom,
                subjectTo: subjectTo,
              );
            } catch (_) {
              File(subjectTo).renameSync(subjectFrom);
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
          } on _MigrationRewriteFailure catch (e) {
            refused++;
            print(
              'zfa tdd migrate-paths: REFUSED for behavior '
              '"${record.behaviorId}" in ${entry.featureName}: '
              '${e.message} The pair was rolled back to its recorded '
              'layout — the command never reports success on an '
              'unloadable suite.',
            );
            updated.add(record);
            continue;
          }
          movedTestToPaths.add(_posix(testTo));
          moves.add(
            _MovedPair(
              record: record,
              plan: plan,
              testFrom: testFrom,
              testTo: testTo,
              subjectFrom: subjectFrom,
              subjectTo: subjectTo,
              updatedIndex: updated.length,
            ),
          );
        }
        migrated++;
        registryDirty = true;
        updated.add(plan.record);
      }

      // -------------------------------------------------------------
      // Post-move pass (issue #912 defect 4), non-dry-run only:
      //   1. cross-pair reference rewrites (composed tests importing
      //      subjects whose own pairs moved later in the loop);
      //   2. the self-check — every moved test's relative and
      //      self-package imports must resolve on disk BEFORE success;
      //      a pair that cannot resolve rolls back and is refused;
      //   3. the cycle-log evidence rewrite, only for pairs that
      //      verified;
      // then the repair pass for already-migrated-but-broken records —
      // which runs EVEN when nothing moved this run (the re-run repair
      // scenario).
      // -------------------------------------------------------------
      if (!dryRun) {
        final pkg = hostPackageName(cwd);
        if (moves.isNotEmpty) {
          // 1. Cross-pair rewrites.
          for (final moved in moves) {
            final file = File(moved.testTo);
            var content = file.readAsStringSync();
            var changed = false;
            for (final other in moves) {
              final oldRel = _posix(
                p.relative(other.subjectFrom, from: p.dirname(moved.testTo)),
              );
              final newRel = _posix(
                p.relative(other.subjectTo, from: p.dirname(moved.testTo)),
              );
              if (oldRel != newRel && content.contains(oldRel)) {
                content = content.replaceAll(oldRel, newRel);
                changed = true;
              }
              if (pkg != null) {
                final oldUri =
                    'package:$pkg/${_posix(p.relative(other.subjectFrom, from: p.join(cwd, 'lib')))}';
                final newUri =
                    'package:$pkg/${_posix(p.relative(other.subjectTo, from: p.join(cwd, 'lib')))}';
                if (oldUri != newUri && content.contains(oldUri)) {
                  content = content.replaceAll(oldUri, newUri);
                  changed = true;
                }
              }
            }
            if (changed) file.writeAsStringSync(content);
          }

          // 2. Self-check with honest rollback.
          final verified = <_MovedPair>[];
          for (final moved in moves) {
            final content = File(moved.testTo).readAsStringSync();
            final issues = unresolvedImports(
              source: content,
              filePath: moved.testTo,
              projectRoot: cwd,
              packageName: pkg,
            );
            final movedBasenames = moves
                .map((m) => p.basename(m.subjectFrom))
                .toSet();
            final fatal = issues
                .where((i) => movedBasenames.contains(_uriBasename(i.uri)))
                .toList();
            if (fatal.isNotEmpty) {
              // Roll the pair back: files, registry record, counters.
              File(moved.subjectTo).renameSync(moved.subjectFrom);
              final testFile = File(moved.testTo);
              final original = File(moved.testTo).readAsStringSync();
              testFile.renameSync(moved.testFrom);
              File(moved.testFrom).writeAsStringSync(original);
              updated[moved.updatedIndex] = moved.record;
              migrated--;
              refused++;
              print(
                'zfa tdd migrate-paths: REFUSED for behavior '
                '"${moved.record.behaviorId}" in ${entry.featureName}: the '
                'moved test still has unresolvable imports for a moved '
                'subject (${fatal.join(', ')}). The pair was rolled back — '
                'the command never reports success on an unloadable suite '
                '(issue #912 defect 4).',
              );
              continue;
            }
            for (final issue in issues) {
              print(
                'zfa tdd migrate-paths: drift hint for '
                '"${moved.record.behaviorId}" in ${entry.featureName}: '
                '${moved.testTo} imports ${issue.uri} which does not '
                'resolve — pre-existing, unrelated to this migration; '
                '`zfa tdd doctor` reports it.',
              );
            }
            verified.add(moved);
          }

          // 3. Cycle-log evidence rewrite for verified pairs.
          for (final moved in verified) {
            try {
              await _rewriteCycleLogPaths(
                featureDir: entry.featureDir,
                cwd: cwd,
                record: moved.record,
                plan: moved.plan,
                testFrom: moved.testFrom,
                testTo: moved.testTo,
                subjectFrom: moved.subjectFrom,
                subjectTo: moved.subjectTo,
              );
            } on FileSystemException catch (e) {
              File(moved.subjectTo).renameSync(moved.subjectFrom);
              final content = File(moved.testTo).readAsStringSync();
              File(moved.testTo).renameSync(moved.testFrom);
              File(moved.testFrom).writeAsStringSync(content);
              updated[moved.updatedIndex] = moved.record;
              migrated--;
              refused++;
              print(
                'zfa tdd migrate-paths: REFUSED for behavior '
                '"${moved.record.behaviorId}" in ${entry.featureName}: the '
                'cycle-log evidence rewrite failed: ${e.message}. The pair '
                'was rolled back.',
              );
              continue;
            }
            _cleanupEmptyLegacyDirs(cwd, moved.plan);
          }
        }

        // -----------------------------------------------------------
        // Repair pass (issue #912, already-migrated-but-broken state):
        // namespaced records whose tests still reference the legacy flat
        // subject location get the stale references rewritten.
        // -----------------------------------------------------------
        final subjectIndex = <String, String>{};
        for (final record in updated) {
          final subjectPath = _resolve(cwd, record.subjectPath);
          if (File(subjectPath).existsSync()) {
            subjectIndex[p.basename(subjectPath)] = subjectPath;
          }
        }
        for (final record in updated) {
          final testPath = _resolve(cwd, record.testPath);
          if (movedTestToPaths.contains(_posix(testPath))) continue;
          final testFile = File(testPath);
          if (!testFile.existsSync()) continue;
          final original = testFile.readAsStringSync();
          final issues = unresolvedImports(
            source: original,
            filePath: testPath,
            projectRoot: cwd,
            packageName: pkg,
          );
          final repairable = issues
              .where((i) => subjectIndex.containsKey(_uriBasename(i.uri)))
              .toList();
          if (repairable.isEmpty) continue;
          var content = original;
          for (final issue in repairable) {
            final target = subjectIndex[_uriBasename(issue.uri)]!;
            final corrected = issue.uri.startsWith('package:')
                ? (pkg == null
                      ? null
                      : 'package:$pkg/${_posix(p.relative(target, from: p.join(cwd, 'lib')))}')
                : _posix(p.relative(target, from: p.dirname(testPath)));
            if (corrected == null || corrected == issue.uri) continue;
            content = content.replaceAll(issue.uri, corrected);
          }
          final leftover =
              unresolvedImports(
                    source: content,
                    filePath: testPath,
                    projectRoot: cwd,
                    packageName: pkg,
                  )
                  .where((i) => subjectIndex.containsKey(_uriBasename(i.uri)))
                  .toList();
          if (leftover.isNotEmpty) {
            refused++;
            print(
              'zfa tdd migrate-paths: REFUSED for behavior '
              '"${record.behaviorId}" in ${entry.featureName}: the '
              'recorded test still references a known subject location '
              'that does not resolve after repair '
              '(${leftover.join(', ')}).',
            );
            continue;
          }
          if (content != original) {
            testFile.writeAsStringSync(content);
            migrated++;
            print(
              'zfa tdd migrate-paths: repaired "${record.behaviorId}" in '
              '${entry.featureName}: stale flat subject references '
              'rewritten to the namespaced layout (issue #912, '
              'already-migrated-but-broken state).',
            );
          }
        }
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
    // Issue #969: the counters ARE the exit taxonomy; label the class.
    _verdict
      ..exitClass = (refused > 0 || missing > 0) ? 'refused' : 'ok'
      ..outcome = (refused > 0 || missing > 0)
          ? VerdictOutcome.fail
          : VerdictOutcome.pass;
    _verdict.details
      ..['migrated'] = migrated
      ..['refused'] = refused
      ..['missing'] = missing
      ..['dry_run'] = dryRun;
    _verdict.feature = featureLabel == 'all' ? null : featureLabel;
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

  /// Rewrite the moved test's subject reference to the namespaced depth —
  /// in BOTH forms (issue #912 defect 4): the relative path (the only form
  /// the pre-#912 command handled) AND the `package:<host>/tdd/...` URI.
  /// Content that does not carry the old reference (a hand-edited or
  /// custom test) is left verbatim.
  ///
  /// Verify-before-write: when the test referenced its subject at all, the
  /// rewritten content must reference it in a RESOLVABLE form (the new
  /// relative path or the new package URI) — otherwise a
  /// [_MigrationRewriteFailure] is thrown and the caller rolls the pair
  /// back. A rewrite that leaves the reference dangling is exactly the
  /// issue #912 defect (success reported on an unloadable suite).
  void _rewriteMovedTestReferences({
    required String cwd,
    required String testFrom,
    required String testTo,
    required String subjectFrom,
    required String subjectTo,
  }) {
    final oldRelative = _posix(
      p.relative(subjectFrom, from: p.dirname(testFrom)),
    );
    final newRelative = _posix(p.relative(subjectTo, from: p.dirname(testTo)));
    final pkg = hostPackageName(cwd);
    final oldLibRel = _posix(p.relative(subjectFrom, from: p.join(cwd, 'lib')));
    final newLibRel = _posix(p.relative(subjectTo, from: p.join(cwd, 'lib')));
    final oldPackageUri = pkg == null ? null : 'package:$pkg/$oldLibRel';
    final newPackageUri = pkg == null ? null : 'package:$pkg/$newLibRel';

    final file = File(testTo);
    final original = file.readAsStringSync();
    var content = original;
    if (oldRelative != newRelative) {
      content = content.replaceAll(oldRelative, newRelative);
    }
    if (oldPackageUri != null &&
        newPackageUri != null &&
        oldPackageUri != newPackageUri) {
      content = content.replaceAll(oldPackageUri, newPackageUri);
    }

    final subjectBasename = p.basename(subjectFrom);
    final referencedSubject =
        original.contains(oldRelative) ||
        importUrisOf(
          original,
        ).any((uri) => _uriBasename(uri) == subjectBasename);
    if (referencedSubject) {
      final resolves =
          content.contains(newRelative) ||
          (newPackageUri != null && content.contains(newPackageUri));
      if (!resolves) {
        throw _MigrationRewriteFailure(
          'the moved test "$_posix(p.relative(testTo, from: cwd))" does '
          'not reference its subject in a resolvable form (expected '
          '"$newRelative" or "${newPackageUri ?? 'a self-package URI'}")',
        );
      }
    }
    if (content != original) {
      file.writeAsStringSync(content);
    }
  }

  /// The basename a URI reference resolves to: the last path segment for
  /// both relative paths and `package:<pkg>/...` URIs.
  static String _uriBasename(String uri) =>
      p.basename(Uri.tryParse(uri)?.path ?? uri);

  /// Rewrite the feature's cycle-log evidence lines that name the moved
  /// paths (`- test:` and `- command:` entries), so certified evidence
  /// keeps pointing at files that exist. Both the recorded form and its
  /// resolved absolute form may appear; both are replaced.
  Future<void> _rewriteCycleLogPaths({
    required String featureDir,
    required String cwd,
    required ArtifactRecord record,
    required _MigrationPlan plan,
    required String testFrom,
    required String testTo,
    required String subjectFrom,
    required String subjectTo,
  }) async {
    final file = File(p.join(featureDir, 'tdd', 'cycle-log.md'));
    if (!await file.exists()) return;
    var raw = await file.readAsString();
    raw = raw
        .replaceAll(record.testPath, plan.testPath)
        .replaceAll(record.subjectPath, plan.subjectPath)
        .replaceAll(testFrom, testTo)
        .replaceAll(subjectFrom, subjectTo);
    await file.writeAsString(raw);
  }

  String _posix(String path) => path.replaceAll(r'\', '/');

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

/// A rewrite failure that would leave a moved test's subject reference
/// dangling (issue #912 defect 4): the pair rolls back and the migration
/// is refused instead of reporting success on an unloadable suite.
class _MigrationRewriteFailure implements Exception {
  const _MigrationRewriteFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One pair moved by THIS run — the post-move pass (cross-pair rewrites,
/// self-check, cycle-log rewrite, rollback) reads these.
class _MovedPair {
  const _MovedPair({
    required this.record,
    required this.plan,
    required this.testFrom,
    required this.testTo,
    required this.subjectFrom,
    required this.subjectTo,
    required this.updatedIndex,
  });

  final ArtifactRecord record;
  final _MigrationPlan plan;
  final String testFrom;
  final String testTo;
  final String subjectFrom;
  final String subjectTo;

  /// The index of the pair's updated record in the registry write list —
  /// a rollback swaps it back to [record].
  final int updatedIndex;
}
