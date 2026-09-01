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
  OwnershipConflict(this.path, this.role, {this.reason});

  /// The absolute or repo-relative path of the conflicting file.
  final String path;

  /// Whether the conflict was on the test or the subject.
  final String role; // 'test' or 'subject'

  /// More specific registry/file mismatch detail, when available.
  final String? reason;

  @override
  String toString() {
    final detail =
        reason ??
        '$role file "$path" exists on disk but the registry has no '
            'recorded ownership';
    return 'OwnershipConflict: $detail. Refusing to overwrite non-owned '
        'content. Run `zfa tdd gen <behavior-id>` after resolving the '
        'conflict.';
  }
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
    final checked = await preflight(record, dryRun: dryRun);
    if (checked.testOwnership == Ownership.created) {
      await _appendRecord(checked);
    }
    return checked;
  }

  /// Check whether [record] can be generated without modifying the registry.
  ///
  /// A prior record is reusable only when its paths match [record] and both
  /// artifacts still exist. Any incomplete or mismatched pair is recoverable
  /// as an [OwnershipConflict], rather than being reported as reused.
  Future<ArtifactRecord> preflight(
    ArtifactRecord record, {
    bool dryRun = false,
  }) async {
    if (dryRun) {
      return record.copyWithOwnership(
        testOwnership: Ownership.planned,
        subjectOwnership: Ownership.planned,
      );
    }

    final existing = await _loadRecords();
    ArtifactRecord? prior;
    for (final candidate in existing) {
      if (candidate.behaviorId == record.behaviorId) {
        prior = candidate;
        break;
      }
    }

    if (prior != null) {
      if (!_samePath(prior.testPath, record.testPath)) {
        throw OwnershipConflict(
          record.testPath,
          'test',
          reason:
              'the registry test path "${prior.testPath}" does not match '
              '"${record.testPath}"',
        );
      }
      if (!_samePath(prior.subjectPath, record.subjectPath)) {
        throw OwnershipConflict(
          record.subjectPath,
          'subject',
          reason:
              'the registry subject path "${prior.subjectPath}" does not '
              'match "${record.subjectPath}"',
        );
      }
      if (!await File(record.testPath).exists()) {
        throw OwnershipConflict(
          record.testPath,
          'test',
          reason:
              'the registry records test file "${record.testPath}", but it '
              'is missing from disk',
        );
      }
      if (!await File(record.subjectPath).exists()) {
        throw OwnershipConflict(
          record.subjectPath,
          'subject',
          reason:
              'the registry records subject file "${record.subjectPath}", '
              'but it is missing from disk',
        );
      }
      return prior.copyWithOwnership(
        testOwnership: Ownership.reused,
        subjectOwnership: Ownership.reused,
      );
    }

    if (await File(record.testPath).exists()) {
      throw OwnershipConflict(record.testPath, 'test');
    }
    if (await File(record.subjectPath).exists()) {
      throw OwnershipConflict(record.subjectPath, 'subject');
    }
    return record.copyWithOwnership(
      testOwnership: Ownership.created,
      subjectOwnership: Ownership.created,
    );
  }

  /// Append a successfully materialized artifact pair.
  ///
  /// Callers must run [preflight] before writing either artifact. This method
  /// refuses to record a pair unless both files are present.
  Future<ArtifactRecord> append(ArtifactRecord record) async {
    final existing = await _loadRecords();
    ArtifactRecord? prior;
    for (final candidate in existing) {
      if (candidate.behaviorId == record.behaviorId) {
        prior = candidate;
        break;
      }
    }
    if (prior != null) {
      return preflight(record);
    }
    if (!await File(record.testPath).exists()) {
      throw StateError(
        'Cannot append artifact record: test file is missing at '
        '${record.testPath}',
      );
    }
    if (!await File(record.subjectPath).exists()) {
      throw StateError(
        'Cannot append artifact record: subject file is missing at '
        '${record.subjectPath}',
      );
    }
    await _writeRecords([...existing, record]);
    return record.copyWithOwnership(
      testOwnership: Ownership.created,
      subjectOwnership: Ownership.created,
    );
  }

  /// Replace the prior record for [record]'s behavior id (or append when no
  /// prior exists) and persist the registry (bug #683).
  ///
  /// `gen` uses this after regenerating a stale stub so the record carries
  /// the CURRENT binary's mtime — the next gen is a silent reuse again.
  /// Unlike [append], a prior record is replaced rather than treated as a
  /// no-op, because regeneration re-writes artifacts the record describes.
  Future<ArtifactRecord> update(ArtifactRecord record) async {
    final existing = await _loadRecords();
    final index = existing.indexWhere(
      (candidate) => candidate.behaviorId == record.behaviorId,
    );
    if (index >= 0) {
      existing[index] = record;
    } else {
      existing.add(record);
    }
    await _writeRecords(existing);
    return record;
  }

  /// Load all records for this feature.
  ///
  /// Returns an empty list if the registry file does not exist (FR-012).
  Future<List<ArtifactRecord>> loadAll() async {
    return _loadRecords();
  }

  /// Find a single record by behavior id. Returns `null` if not found.
  Future<ArtifactRecord?> findRecord(String behaviorId) async {
    final records = await _loadRecords();
    for (final r in records) {
      if (r.behaviorId == behaviorId) return r;
    }
    return null;
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
    try {
      await tmpFile.writeAsString(raw);
      await tmpFile.rename(file.path);
    } catch (_) {
      if (await tmpFile.exists()) await tmpFile.delete();
      rethrow;
    }
  }

  Future<void> _appendRecord(ArtifactRecord record) async {
    final existing = await _loadRecords();
    await _writeRecords([...existing, record]);
  }

  bool _samePath(String left, String right) =>
      p.equals(p.normalize(left), p.normalize(right));
}
