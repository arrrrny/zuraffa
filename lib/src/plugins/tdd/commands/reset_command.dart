/// `zfa tdd reset <feature>` — first-class recovery: revert a feature's
/// TDD state to clean (bug #840).
///
/// The command:
///   1. Resolves the feature directory (`specs/<feature>`) and loads the
///      artifact registry BEFORE touching anything.
///   2. Normalizes every recorded path against the project root (issue
///      #1331): a RELATIVE recorded path must resolve against the
///      project root — never against the invoking process's CWD — and an
///      ABSOLUTE path recorded by another checkout resolves as-is. Both
///      forms are the same ownership answer (the #912/#1312 class).
///   3. Scans the generated layouts (`test/tdd`, `lib/tdd` —
///      recursively, the namespaced layout lives in feature
///      subdirectories) for generated-shape files whose provenance
///      header names a DROPPED behavior id: a path-drifted file is still
///      owned by the reset and is deleted (issue #1331). A drifted file
///      another feature's live registry owns is foreign-owned — kept and
///      reported by name, never deleted (bug #874).
///   4. Prints the diff summary — every registry record it will drop,
///      every owned file it will delete, every path-drift warning, and
///      every foreign-but-owned-looking file BY NAME — BEFORE acting.
///      Files on disk that no record and no provenance header tie to a
///      dropped behavior are FOREIGN: counted, reported as kept, and
///      never deleted.
///   5. Deletes the owned files, drops the registry
///      (`tdd/artifacts.json`) and the feature's run-state
///      (`tdd/run-state.json`) — the two mutable stores a restart needs
///      clean. The cycle-log is append-only evidence and is never
///      touched; the audit log is history and is never touched.
///   6. Appends a reset TOMBSTONE to the unified journal
///      (`tdd/journal.json`, issue #1264): one entry naming every
///      dropped behavior id, invalidating the green evidence those
///      behaviors left behind in the cycle-log. Without it the run
///      driver re-derives done from the surviving evidence and skips the
///      dropped behaviors as "already done" (the phantom done-state). The
///      tombstone is append-only — the journal's history stays intact.
///   7. Validates its own outcome (issue #1331): every planned deletion
///      is re-statted after acting — the reported deleted-file count
///      matches the printed "will delete N owned files" list, and any
///      survivor is named in a warning instead of being silently kept.
///   8. Emits the machine-readable JSON verdict as the final stdout line
///      and exits 0 on success, 1 on refusal (unknown feature).
///
/// Ownership rule (hard constraint): reset NEVER deletes foreign files —
/// the delete set is exactly the union of the dropped registry records'
/// paths (normalized) that exist on disk, plus the generated-shape files
/// whose provenance names a dropped behavior id and that no OTHER
/// feature's registry owns.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/artifact_registry.dart';
import '../services/cross_feature_ownership.dart';
import '../services/generated_shape.dart';
import '../services/journal.dart';
import '../services/verdict_emitter.dart';
import '../models/verdict_envelope.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

class ResetCommand extends Command<void> {
  ResetCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
      negatable: false,
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and lib/. When omitted, '
          'the current working directory is used.',
    );
  }

  bool _jsonMode = false;

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit (the
  /// legacy raw-JSON verdict line folds into it — ONE machine line).
  final VerdictContext _verdict = VerdictContext();

  @override
  String get name => 'reset';

  @override
  String get description =>
      'Revert a feature\'s TDD state to clean: drop the artifact registry '
      'entries and the generated tests/subjects the registry owns, reset '
      'run-state, and NEVER touch foreign files (bug #840). Prints the '
      'diff summary before acting.';

  @override
  String get invocation => 'zfa tdd reset <feature> [--project <path>]';

  @override
  Future<void> run() =>
      runWithVerdictEnvelope(this, _verdict, _run, featureFromRest: true);

  Future<void> _run() async {
    final rest = argResults?.rest ?? const <String>[];
    _jsonMode = argResults?['json'] as bool? ?? false;
    if (rest.isEmpty) {
      usageException(
        'Feature name is required: zfa tdd reset <feature> '
        '(e.g. 049-tdd-run)',
      );
    }
    final feature = rest.first;
    final projectFlag = argResults?['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    final featureDir = p.join(cwd, 'specs', feature);

    if (!await Directory(featureDir).exists()) {
      print('zfa tdd reset: no feature directory at specs/$feature');
      _printVerdict(
        feature: feature,
        verdict: 'refused',
        reason: 'no feature directory at specs/$feature',
      );
      _verdict.fix =
          'create the feature (zfa tdd init / a spec) or check '
          'the feature name';
      exitCode = 1;
      return;
    }

    final registry = ArtifactRegistry(featureDir: featureDir);
    final records = await registry.loadAll();
    final droppedIds = records.map((record) => record.behaviorId).toList();

    // Issue #1331: the delete set starts from the recorded paths
    // NORMALIZED against the project root. The raw `File(path)` check
    // resolved a relative recorded path against the PROCESS CWD and an
    // absolute path from another checkout as-is — records whose paths
    // no longer matched were dropped while their files silently stayed
    // (the half-state the documented reset → run recovery loop could
    // never re-drive).
    final ownedExisting = <String>[];
    // Per dropped record: the recorded paths that did NOT exist at reset
    // time (the path-drift class the old reset kept silent about).
    final pathDrift = <String>[];
    // Issue #1380: the namespace agreement applies to the RECORDED paths
    // too — a poisoned/stale record naming another feature's namespace is
    // path drift (kept + warned), never a delete.
    String? foreignNamespaceSegment(String normalized) {
      for (final lane in ['test/tdd', 'lib/tdd']) {
        final laneAbs = p.join(cwd, lane);
        if (p.isWithin(laneAbs, normalized)) {
          final segments = p.relative(normalized, from: laneAbs).split('/');
          if (segments.length >= 2) return segments.first;
        }
      }
      return null;
    }

    for (final record in records) {
      for (final (role, raw) in [
        ('test', record.testPath),
        ('subject', record.subjectPath),
      ]) {
        final normalized = normalizeArtifactPath(cwd, raw);
        if (File(normalized).existsSync()) {
          final foreignSegment = foreignNamespaceSegment(normalized);
          if (foreignSegment != null && foreignSegment != feature) {
            pathDrift.add(
              '${record.behaviorId}: recorded $role path '
              '${_displayPath(cwd, normalized)} is in another '
              'feature\'s namespace ($foreignSegment) — kept, never '
              'deleted',
            );
            continue;
          }
          if (!ownedExisting.contains(normalized)) {
            ownedExisting.add(normalized);
          }
        } else {
          pathDrift.add(
            '${record.behaviorId}: recorded $role path '
            '${_displayPath(cwd, normalized)} did not exist at reset time',
          );
        }
      }
    }

    // Issue #1331: recover the path-drifted files. A generated-shape
    // file whose provenance header names a DROPPED behavior id is owned
    // by this reset even when its recorded path no longer matches — the
    // provenance header is the durable ownership marker (the same
    // two-signal check gen's --adopt verifies). A drifted file ANOTHER
    // feature's live registry owns is foreign-owned: kept and reported
    // by name, never deleted (bug #874).
    final scan = await _findDriftedOwnedFiles(
      cwd: cwd,
      feature: feature,
      droppedIds: droppedIds.toSet(),
      alreadyOwned: ownedExisting,
    );
    final recoveredDrifted = scan.recoveredById.values
        .expand((paths) => paths)
        .toList();
    final deleteSet = [...ownedExisting, ...recoveredDrifted];
    final foreignKept = _countForeignGeneratedFiles(cwd, deleteSet);

    // Diff summary BEFORE acting (bug #840) — now with the drift
    // warnings the old reset omitted (issue #1331).
    print('zfa tdd reset: feature $feature (specs/$feature/tdd)');
    print('  will drop ${records.length} registry record(s):');
    for (final record in records) {
      print('    - ${record.behaviorId} (${record.testPath})');
    }
    print('  will delete ${deleteSet.length} owned file(s):');
    for (final path in deleteSet) {
      print('    - ${_displayPath(cwd, path)}');
    }
    for (final drift in pathDrift) {
      print('  path drift: $drift');
    }
    for (final entry in scan.recoveredById.entries) {
      if (entry.value.isEmpty) continue;
      print(
        '  path drift: ${entry.key} — drifted artifacts recovered by the '
        'provenance scan and deleted: '
        '${entry.value.map((path_) => _displayPath(cwd, path_)).join(', ')}',
      );
    }
    for (final entry in scan.foreignOwnedLookingById.entries) {
      if (entry.value.isEmpty) continue;
      print(
        '  path drift: ${entry.key} — foreign-but-owned-looking file(s) '
        'kept (another feature\'s registry owns them): '
        '${entry.value.map((path_) => _displayPath(cwd, path_)).join(', ')}',
      );
    }
    print('  will reset tdd/run-state.json');
    print(
      '  will keep $foreignKept foreign generated file(s) untouched '
      '(never deleted)',
    );
    // Issue #1264: the dropped behaviors' surviving cycle-log evidence is
    // invalidated (the journal tombstone) — announced BEFORE acting, like
    // every other reset effect.
    if (droppedIds.isNotEmpty) {
      print(
        '  will invalidate the green evidence of ${droppedIds.length} '
        'dropped behavior(s) (journal tombstone)',
      );
    }

    // Act: owned files first, then the registry, then run-state.
    final actuallyDeleted = <String>[];
    final survivors = <String>[];
    for (final path in deleteSet) {
      try {
        await File(path).delete();
        actuallyDeleted.add(path);
      } on FileSystemException {
        // Issue #1331 outcome validation: a deletion that did not land
        // is named, never silently swallowed.
        survivors.add(path);
      }
    }
    for (final path in survivors) {
      print(
        '  reset validation: FAILED to delete '
        '${_displayPath(cwd, path)} — the file survives on disk',
      );
    }
    if (survivors.isNotEmpty) {
      // A surviving owned file must NOT lose its registry record: with
      // the registry dropped, the survivor is outside every future
      // reset's delete set forever (the orphan class). Retain the
      // registry and run-state, skip the tombstone (the behaviors are
      // NOT invalidated — they still own their records), and fail.
      print(
        '  reset validation: ${survivors.length} owned file(s) survived — '
        'the registry and run-state are RETAINED so a later reset still '
        'owns them. --> fix: resolve the cause (permissions, locks, a '
        'running process holding the file), then re-run '
        '`zfa tdd reset $feature`.',
      );
      _printVerdict(
        feature: feature,
        verdict: 'refused',
        reason: '${survivors.length} owned file(s) survived deletion',
        droppedFiles: deleteSet
            .map((path_) => _displayPath(cwd, path_))
            .toList(),
        droppedRecords: records.length,
        foreignKept: foreignKept,
        invalidatedBehaviors: const [],
        deletedFiles: actuallyDeleted
            .map((path_) => _displayPath(cwd, path_))
            .toList(),
        pathDrift: pathDrift,
        foreignOwnedLooking: scan.foreignOwnedLookingById.values
            .expand((paths) => paths)
            .map((path_) => _displayPath(cwd, path_))
            .toList(),
      );
      exitCode = 1;
      return;
    }
    final registryFile = File(registry.registryPath);
    if (await registryFile.exists()) await registryFile.delete();
    final runStateFile = File(p.join(featureDir, 'tdd', 'run-state.json'));
    if (await runStateFile.exists()) await runStateFile.delete();

    // Issue #1264: tombstone the dropped behaviors — append the journal
    // entry that invalidates their surviving green evidence, so the run
    // driver re-drives them instead of skipping them as "already done".
    await JournalWriter(
      featureDir,
    ).appendResetTombstone(behaviorIds: droppedIds);

    // Issue #1331: the reported count is the ACTUAL deletion count —
    // the printed "will delete N owned files" list must match what was
    // really deleted.
    print(
      'zfa tdd reset: feature=$feature dropped=${records.length} '
      'deleted=${actuallyDeleted.length}',
    );
    _printVerdict(
      feature: feature,
      verdict: 'reset',
      droppedFiles: deleteSet.map((path_) => _displayPath(cwd, path_)).toList(),
      droppedRecords: records.length,
      foreignKept: foreignKept,
      invalidatedBehaviors: droppedIds,
      deletedFiles: actuallyDeleted
          .map((path_) => _displayPath(cwd, path_))
          .toList(),
      pathDrift: pathDrift,
      foreignOwnedLooking: scan.foreignOwnedLookingById.values
          .expand((paths) => paths)
          .map((path_) => _displayPath(cwd, path_))
          .toList(),
    );
    exitCode = 0;
  }

  /// Issue #1331: scan the generated layouts (`test/tdd`, `lib/tdd` —
  /// recursively: the namespaced layout lives in feature
  /// subdirectories) for generated-shape files whose provenance header
  /// names one of the DROPPED behavior ids. Returns the drifted owned
  /// files per behavior id (deleted by the reset) and the
  /// foreign-but-owned-looking files per behavior id (another feature's
  /// live registry owns them — kept and reported, never deleted).
  Future<
    ({
      Map<String, List<String>> recoveredById,
      Map<String, List<String>> foreignOwnedLookingById,
    })
  >
  _findDriftedOwnedFiles({
    required String cwd,
    required String feature,
    required Set<String> droppedIds,
    required List<String> alreadyOwned,
  }) async {
    final recoveredById = <String, List<String>>{};
    final foreignOwnedLookingById = <String, List<String>>{};
    // Cross-registry safety (bug #874): another feature's live registry
    // owning the path makes it foreign-owned — adopting it into this
    // reset's delete set would corrupt ownership. The ownership map is
    // built ONCE (each per-file query would reload every registry).
    final ownersByPath = await ownershipByPathAcrossFeatures(cwd);
    for (final dir in [p.join(cwd, 'test', 'tdd'), p.join(cwd, 'lib', 'tdd')]) {
      final d = Directory(dir);
      if (!d.existsSync()) continue;
      for (final entity in d.listSync(recursive: true).whereType<File>()) {
        if (!entity.path.endsWith('.dart')) continue;
        final normalized = p.normalize(entity.path);
        if (alreadyOwned.contains(normalized)) continue;
        String content;
        try {
          content = entity.readAsStringSync();
        } on FileSystemException {
          continue;
        }
        final id = behaviorIdFromContent(content);
        if (id == null || !droppedIds.contains(id)) continue;
        final shaped =
            matchesGeneratedTestShape(content, id) ||
            matchesGeneratedSubjectShape(content, id);
        if (!shaped) continue;
        // Issue #1380: a bare behavior id (A1, U1, ...) is SHARED across
        // features — a generated-shape file under ANOTHER feature's
        // namespace (test/tdd/<other-feature>/…) is foreign even when
        // its header names a dropped id, and even when no live registry
        // owns it. The namespace segment after the lane root must equal
        // the feature being reset; flat (pre-namespaced) candidates keep
        // the header-match behavior.
        final laneRelative = p.relative(normalized, from: dir);
        final segments = laneRelative.split('/');
        if (segments.length >= 2 && segments.first != feature) {
          foreignOwnedLookingById.putIfAbsent(id, () => []).add(normalized);
          continue;
        }
        final owner = ownersByPath[normalizeArtifactPath(cwd, normalized)];
        if (owner != null && owner != feature) {
          foreignOwnedLookingById.putIfAbsent(id, () => []).add(normalized);
          continue;
        }
        recoveredById.putIfAbsent(id, () => []).add(normalized);
      }
    }
    return (
      recoveredById: recoveredById,
      foreignOwnedLookingById: foreignOwnedLookingById,
    );
  }

  /// The path relative to the project root, POSIX separators (the display
  /// and verdict form for reset's artifacts).
  String _displayPath(String cwd, String absolute) =>
      p.relative(absolute, from: cwd).replaceAll(r'\', '/');

  /// Count generated-layout files on disk that are NOT in the owned delete
  /// set — the foreign files reset keeps (reported, never touched).
  /// Issue #1331: the scan is RECURSIVE (the namespaced layout lives in
  /// feature subdirectories the flat listing never saw) and compares
  /// normalized paths (the delete set's form).
  int _countForeignGeneratedFiles(String cwd, List<String> owned) {
    var foreign = 0;
    for (final dir in [p.join(cwd, 'test', 'tdd'), p.join(cwd, 'lib', 'tdd')]) {
      final d = Directory(dir);
      if (!d.existsSync()) continue;
      for (final entity in d.listSync(recursive: true).whereType<File>()) {
        if (!owned.contains(p.normalize(entity.path))) foreign++;
      }
    }
    return foreign;
  }

  /// The machine-readable verdict (bug #840) — text when --json is
  /// absent; the envelope details when it is set (issue #969: ONE
  /// versioned machine line, never a second raw object).
  void _printVerdict({
    required String feature,
    required String verdict,
    String? reason,
    List<String> droppedFiles = const [],
    int droppedRecords = 0,
    int foreignKept = 0,
    List<String> invalidatedBehaviors = const [],
    List<String> deletedFiles = const [],
    List<String> pathDrift = const [],
    List<String> foreignOwnedLooking = const [],
  }) {
    if (!_jsonMode) {
      print(
        'reset: feature=$feature verdict=$verdict'
        '${reason != null ? ' reason="$reason"' : ''}'
        ' dropped_records=$droppedRecords'
        ' foreign_files_kept=$foreignKept',
      );
      return;
    }
    _verdict
      ..feature = feature
      ..outcome = verdict == 'refused'
          ? VerdictOutcome.fail
          : VerdictOutcome.pass
      ..exitClass = verdict == 'refused' ? 'refused' : 'ok';
    _verdict.details
      ..['verdict'] = verdict
      ..['dropped_records'] = droppedRecords
      ..['foreign_files_kept'] = foreignKept;
    if (reason != null) _verdict.details['reason'] = reason;
    if (droppedFiles.isNotEmpty) {
      _verdict.details['dropped_files'] = droppedFiles;
    }
    if (invalidatedBehaviors.isNotEmpty) {
      _verdict.details['invalidated_behaviors'] = invalidatedBehaviors;
    }
    // Issue #1331: the outcome-validation details — the ACTUAL deletions
    // (the printed will-delete list, proved), the per-record path-drift
    // warnings, and the foreign-but-owned-looking files reported by name.
    if (deletedFiles.isNotEmpty) {
      _verdict.details['deleted_files'] = deletedFiles;
    }
    if (pathDrift.isNotEmpty) {
      _verdict.details['path_drift'] = pathDrift;
    }
    if (foreignOwnedLooking.isNotEmpty) {
      _verdict.details['foreign_owned_looking'] = foreignOwnedLooking;
    }
  }
}
