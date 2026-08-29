/// ArtifactRegistry — append-only store of [ArtifactRecord]s at
/// `specs/<feature>/tdd/artifacts.json` (spec 044-test-tdd-generation,
/// FR-005, FR-006, FR-007, FR-008, FR-009, FR-012).
///
/// The registry is the durable link between `gen` (the writer) and
/// `verify`/`run` (the readers). `gen` appends one record per behavior;
/// a repeat `gen` for the same behavior is a no-op that returns
/// [Ownership.reused] for both artifacts without modifying the registry.
///
/// Ownership conflict (FR-008): if a file exists on disk but the registry
/// has no record for it, [register] throws [OwnershipConflict] and the
/// caller is expected to leave the file untouched.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/artifact_record.dart';
import '../models/ownership.dart';

/// Thrown when a file exists on disk but the registry has no record for it
/// (FR-008). The caller must leave the file untouched.
class OwnershipConflict implements Exception {
  OwnershipConflict(this.path, this.role);

  /// The absolute or repo-relative path of the conflicting file.
  final String path;

  /// Whether the conflict was on the test or the subject.
  final String role; // 'test' or 'subject'

  @override
  String toString() =>
      'OwnershipConflict: $role file "$path" exists on disk but the '
      'registry has no recorded ownership. Refusing to overwrite '
      'non-owned content. Run `zfa tdd gen <behavior-id>` after '
      'resolving the conflict (e.g. by deleting the file or by '
      'registering it explicitly).';
}

/// Append-only registry of [ArtifactRecord]s for a feature.
class ArtifactRegistry {
  /// Construct a registry for a feature directory.
  ///
  /// [featureDir] is the absolute path to the feature's spec directory,
  /// e.g. `/repo/specs/044-test-tdd-generation`. The registry file lives
  /// at `<featureDir>/tdd/artifacts.json`.
  const ArtifactRegistry({required this.featureDir});

  /// Absolute path to the feature spec directory.
  final String featureDir;

  /// Absolute path to the registry file.
  String get registryPath => p.join(featureDir, 'tdd', 'artifacts.json');

  /// Register a record. Returns the record with updated ownership values
  /// reflecting what actually happened on disk.
  ///
  /// Behavior:
  /// - If a record for the same behavior id already exists AND both the
  ///   test and subject files exist on disk, the registration is a no-op
  ///   and the returned record has [Ownership.reused] for both. The
  ///   registry file is NOT modified.
  /// - If the behavior id is new BUT the test or subject file already
  ///   exists on disk without a corresponding record, throws
  ///   [OwnershipConflict] and the registry file is NOT modified.
  /// - Otherwise, appends the record to the registry and returns it with
  ///   [Ownership.created] for both (or [Ownership.planned] if
  ///   [dryRun] is true).
  ///
  /// When [dryRun] is true, no file is written and no registry entry is
  /// created; the returned record carries [Ownership.planned] for both
  /// artifacts (FR-009).
  Future<ArtifactRecord> register(
    ArtifactRecord record, {
    bool dryRun = false,
  }) async {
    if (dryRun) {
      return record.copyWithOwnership(
        testOwnership: Ownership.planned,
        subjectOwnership: Ownership.planned,
      );
    }

    // Load the existing registry (if any).
    final existing = await _loadRecords();
    final hasPrior = existing.any((r) => r.behaviorId == record.behaviorId);

    if (hasPrior) {
      // Idempotent repeat (FR-006): the registry already has an entry for
      // this behavior id. Return reused for both artifacts, without
      // modifying the registry or any files. The registry is the source
      // of truth; we do not check file existence here. (If the user
      // deleted the files but kept the registry entry, they should
      // delete the registry entry too before re-running `gen`.)
      return record.copyWithOwnership(
        testOwnership: Ownership.reused,
        subjectOwnership: Ownership.reused,
      );
    }

    // Ownership conflict check (FR-008): file exists on disk, but the
    // registry has no record for this behavior+file pair. Refuse to
    // overwrite non-owned content.
    final testExists = await File(record.testPath).exists();
    final subjectExists = await File(record.subjectPath).exists();
    if (testExists) {
      throw OwnershipConflict(record.testPath, 'test');
    }
    if (subjectExists) {
      throw OwnershipConflict(record.subjectPath, 'subject');
    }

    // Append the record to the registry.
    final newRecords = [...existing, record];
    await _writeRecords(newRecords);
    return record.copyWithOwnership(
      testOwnership: Ownership.created,
      subjectOwnership: Ownership.created,
    );
  }

  /// Load all records for this feature.
  ///
  /// Returns an empty list if the registry file does not exist (FR-012).
  Future<List<ArtifactRecord>> loadAll() async {
    return _loadRecords();
  }

  Future<List<ArtifactRecord>> _loadRecords() async {
    final file = File(registryPath);
    if (!await file.exists()) return [];
    try {
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final records = (raw['records'] as List?) ?? [];
      return records
          .map((r) => ArtifactRecord.fromJson(r as Map<String, dynamic>))
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> _writeRecords(List<ArtifactRecord> records) async {
    final file = File(registryPath);
    await file.parent.create(recursive: true);
    final raw = jsonEncode({
      'feature': p.basename(featureDir),
      'records': records.map((r) => r.toJson()).toList(),
    });
    // Use a write-and-rename to avoid partial writes.
    final tmpFile = File('${file.path}.tmp');
    await tmpFile.writeAsString(raw);
    await tmpFile.rename(file.path);
  }
}
