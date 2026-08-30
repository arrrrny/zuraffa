/// SliceMerger (spec 043): hash-compare + copy-back (FR-008).
///
/// Iterates the manifest files, runs the 3-way decision per file, copies
/// safe files back, warns on shared-file modifications (U42), reports
/// conflicts without overwriting (U43/A7), merges agent-created and
/// agent-deleted files (U67/U68, the 2026-08-29 recorded decision), and
/// deletes the sandbox on a clean merge (U44/A8).
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../merger/conflict_detector.dart';
import '../models/slice_file.dart';
import '../models/slice_manifest.dart';

/// The outcome of one merge.
class MergeReport {
  /// Creates the report.
  const MergeReport({
    required this.copied,
    required this.conflicts,
    required this.deleted,
    required this.created,
    required this.skipped,
    required this.unconfirmedShared,
    required this.warnings,
    required this.noChanges,
    required this.message,
  });

  /// Creates the nothing-changed report.
  const MergeReport.noChanges(String message)
    : this(
        copied: const [],
        conflicts: const [],
        deleted: const [],
        created: const [],
        skipped: const [],
        unconfirmedShared: const [],
        warnings: const [],
        noChanges: true,
        message: message,
      );

  /// Safe-copied files (relative paths).
  final List<String> copied;

  /// Conflicted files: reported, not copied.
  final List<String> conflicts;

  /// Files deleted from the project (agent deletions).
  final List<String> deleted;

  /// Agent-created files copied back.
  final List<String> created;

  /// Unchanged files.
  final List<String> skipped;

  /// Shared files whose write/delete was not confirmed.
  final List<String> unconfirmedShared;

  /// Non-fatal warnings (branch mismatch, etc.).
  final List<String> warnings;

  /// True when nothing changed at all.
  final bool noChanges;

  /// Human-readable summary.
  final String? message;

  /// Whether the merge completed without anything blocking it.
  bool get clean => conflicts.isEmpty && unconfirmedShared.isEmpty;
}

/// Merges sandbox changes back into the main project.
class SliceMerger {
  /// Creates the merger with an injectable detector.
  SliceMerger({ConflictDetector? detector})
    : _detector = detector ?? ConflictDetector();

  final ConflictDetector _detector;

  /// Merges [sandboxDir] back into the project at [projectRoot].
  ///
  /// [confirmSharedOverwrite] and [confirmSharedDelete] gate every
  /// shared-file mutation (U42, U68); owned files are applied directly.
  Future<MergeReport> merge({
    required SliceManifest manifest,
    required String sandboxDir,
    required String projectRoot,
    required bool Function(SliceFile file) confirmSharedOverwrite,
    required bool Function(String path) confirmSharedDelete,
  }) async {
    final copied = <String>[];
    final conflicts = <String>[];
    final deleted = <String>[];
    final created = <String>[];
    final skipped = <String>[];
    final unconfirmed = <String>[];

    final warnings = <String?>[
      _detector.branchWarning(
        manifestBranch: manifest.branch,
        currentBranch: _currentBranch(projectRoot),
      ),
    ].whereType<String>().toList();

    final known = {
      ...manifest.files.map((f) => f.relativePath),
      ...manifest.generatedFiles,
    };

    for (final file in manifest.files) {
      final sandboxPath = p.join(sandboxDir, file.relativePath);
      final mainPath = p.join(projectRoot, file.relativePath);
      final sandboxHash = _hashIfExists(sandboxPath);
      final mainHash = _hashIfExists(mainPath);

      switch (_detector.decide(
        cutHash: file.hashAtCut,
        sandboxHash: sandboxHash,
        mainHash: mainHash,
      )) {
        case MergeDecision.skip:
          skipped.add(file.relativePath);
        case MergeDecision.safeCopy:
          if (file.ownership == FileOwnership.shared &&
              !confirmSharedOverwrite(file)) {
            unconfirmed.add('shared file not confirmed: ${file.relativePath}');
            break;
          }
          await _copy(sandboxPath, mainPath);
          copied.add(file.relativePath);
        case MergeDecision.conflict:
          conflicts.add(file.relativePath);
        case MergeDecision.sandboxDeleted:
          if (file.ownership == FileOwnership.shared &&
              !confirmSharedDelete(file.relativePath)) {
            unconfirmed.add(
              'shared deletion not confirmed: ${file.relativePath}',
            );
            break;
          }
          final target = File(mainPath);
          if (await target.exists()) {
            await target.delete();
          }
          deleted.add(file.relativePath);
        case MergeDecision.agentCreated:
          // Handled by the sandbox scan below.
          break;
      }
    }

    // Agent-created files: sandbox files outside the manifest and the
    // generated harness (U67). Export artifacts (the filtered pubspec and
    // the README staged from SLICE.md by `slice export`) are generated, not
    // agent work — they must never be merged back over the project.
    const exportArtifacts = {'pubspec.yaml', 'README.md'};
    final sandboxRoot = Directory(sandboxDir);
    if (await sandboxRoot.exists()) {
      for (final entity in sandboxRoot.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final rel = p.relative(entity.path, from: sandboxDir);
        if (rel.split(p.separator).contains('.git')) continue;
        if (known.contains(rel) || exportArtifacts.contains(rel)) continue;
        final target = p.join(projectRoot, rel);
        if (File(target).existsSync()) {
          conflicts.add(rel);
          continue;
        }
        created.add(rel);
        await _copy(entity.path, target);
      }
    }

    final report = MergeReport(
      copied: copied,
      conflicts: conflicts,
      deleted: deleted,
      created: created,
      skipped: skipped,
      unconfirmedShared: unconfirmed,
      warnings: warnings,
      noChanges:
          copied.isEmpty &&
          conflicts.isEmpty &&
          deleted.isEmpty &&
          created.isEmpty &&
          unconfirmed.isEmpty,
      message: _summarize(copied, created, deleted, conflicts, unconfirmed),
    );

    if (report.noChanges) {
      await _deleteDir(sandboxDir);
      return MergeReport.noChanges(
        'No changes to merge for slice "${manifest.name}" — sandbox deleted.',
      );
    }

    if (report.clean) {
      await _deleteDir(sandboxDir);
    }

    return report;
  }

  String _summarize(
    List<String> copied,
    List<String> created,
    List<String> deleted,
    List<String> conflicts,
    List<String> unconfirmed,
  ) {
    final parts = <String>[];
    if (copied.isNotEmpty) {
      parts.add('${copied.length} file(s) copied back');
    }
    if (created.isNotEmpty) {
      parts.add('${created.length} agent-created file(s) merged');
    }
    if (deleted.isNotEmpty) {
      parts.add('${deleted.length} file(s) deleted');
    }
    if (conflicts.isNotEmpty) {
      parts.add('${conflicts.length} conflict(s) preserved in the sandbox');
    }
    if (unconfirmed.isNotEmpty) {
      parts.add(
        '${unconfirmed.length} shared change(s) skipped (not confirmed)',
      );
    }
    return parts.join(', ');
  }

  String? _hashIfExists(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    return sha256.convert(file.readAsBytesSync()).toString();
  }

  String _currentBranch(String projectRoot) {
    final gitHead = File(p.join(projectRoot, '.git', 'HEAD'));
    if (gitHead.existsSync()) {
      final content = gitHead.readAsStringSync().trim();
      if (content.startsWith('ref: refs/heads/')) {
        return content.substring('ref: refs/heads/'.length);
      }
    }
    return 'unknown';
  }

  Future<void> _copy(String from, String to) async {
    final target = File(to);
    await target.parent.create(recursive: true);
    await File(from).copy(to);
  }

  Future<void> _deleteDir(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
