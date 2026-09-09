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
import 'run_state_store.dart';

/// Normalizes a recorded artifact path to the absolute form used for
/// ownership comparisons. Registries may record absolute paths (older
/// binaries' gen) or project-relative ones; both must resolve to the same
/// ownership answer. Relative forms resolve against [projectRoot] — never
/// the process CWD, which is whatever directory the CLI ran from
/// (issue #1397).
String normalizeArtifactPath(String projectRoot, String recorded) =>
    p.isAbsolute(recorded)
    ? p.normalize(recorded)
    : p.normalize(p.join(projectRoot, recorded));

/// The portable persisted form of a recorded artifact path (issue #1397):
/// project-relative POSIX when the path resolves inside [projectRoot],
/// otherwise the normalized recorded form (a path outside the project
/// root cannot be made root-relative without escaping the project).
String canonicalArtifactPath(String projectRoot, String recorded) {
  final absolute = normalizeArtifactPath(projectRoot, recorded);
  final rel = p.relative(absolute, from: projectRoot).replaceAll(r'\', '/');
  return rel == '.' || rel.startsWith('..') ? absolute : rel;
}

/// Probes for a RELOCATED artifact (issue #1397): a committed
/// machine-absolute path whose project root does not exist on this machine
/// (a checkout moved between machines), while the file sits at the same
/// project-relative location under [projectRoot]. Returns the absolute
/// path of the longest directory suffix of [recorded] that resolves to the
/// recorded file under [projectRoot], or null when nothing matches — a
/// genuinely missing artifact. A suffix shorter than `<dir>/<file>` is
/// never accepted: a bare-basename match could re-own a stranger's file.
String? probeRelocatedArtifact(String projectRoot, String recorded) {
  if (!p.isAbsolute(recorded)) return null;
  final segments = p
      .normalize(recorded)
      .split(RegExp(r'[\\/]'))
      .where((s) => s.isNotEmpty)
      .toList();
  for (var i = 0; i + 2 <= segments.length; i++) {
    final candidate = p.join(projectRoot, segments.skip(i).join(p.separator));
    if (File(candidate).existsSync()) return p.normalize(candidate);
  }
  return null;
}

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
  const ArtifactRegistry({required this.featureDir, this.projectRoot});

  /// Absolute path to the feature spec directory.
  final String featureDir;

  /// Explicit project root override (issue #1397). Null means derive from
  /// [resolvedProjectRoot] — the standard `<projectRoot>/specs/<feature>`
  /// layout.
  final String? projectRoot;

  /// The project root recorded artifact paths resolve against (issue
  /// #1397). Null means derive: the standard TDD layout anchors every
  /// feature directory at `<projectRoot>/specs/<feature>`, so the parent
  /// of `specs/` is the root — the same rule `ProjectRoot.find` and every
  /// registry-scanning command apply. Relative recorded paths must NEVER
  /// resolve against the process CWD: the CLI can run from anywhere.
  String get resolvedProjectRoot =>
      projectRoot ?? p.dirname(p.dirname(p.normalize(featureDir)));

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
              '"${record.testPath}"'
              '${_legacyHint(prior.testPath, record.testPath)}',
        );
      }
      if (!_samePath(prior.subjectPath, record.subjectPath)) {
        throw OwnershipConflict(
          record.subjectPath,
          'subject',
          reason:
              'the registry subject path "${prior.subjectPath}" does not '
              'match "${record.subjectPath}"'
              '${_legacyHint(prior.subjectPath, record.subjectPath)}',
        );
      }
      if (!await File(_locate(record.testPath)).exists()) {
        throw OwnershipConflict(
          record.testPath,
          'test',
          reason:
              'the registry records test file "${record.testPath}", but it '
              'is missing from disk',
        );
      }
      if (!await File(_locate(record.subjectPath)).exists()) {
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

    if (await File(_locate(record.testPath)).exists()) {
      throw OwnershipConflict(record.testPath, 'test');
    }
    if (await File(_locate(record.subjectPath)).exists()) {
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
    if (!await File(_locate(record.testPath)).exists()) {
      throw StateError(
        'Cannot append artifact record: test file is missing at '
        '${record.testPath}',
      );
    }
    if (!await File(_locate(record.subjectPath)).exists()) {
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
      // Issue #1397: every persisted record carries the portable
      // project-relative POSIX form — a committed registry must survive
      // another machine, and the ownership gate compares resolved paths.
      'records': records.map((r) => _canonicalize(r).toJson()).toList(),
    });
    // Use a write-and-rename to avoid partial writes. Bug #828: the tmp
    // file is fsync'd before the rename so a registered artifact pair
    // survives the crash that interrupts the run.
    final tmpFile = File('${file.path}.tmp');
    try {
      await tmpFile.writeAsString(raw);
      await flushToDisk(tmpFile);
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

  bool _samePath(String left, String right) => p.equals(
    normalizeArtifactPath(resolvedProjectRoot, left),
    normalizeArtifactPath(resolvedProjectRoot, right),
  );

  /// A recorded path resolved for on-disk checks: absolute against the
  /// project root — never the process CWD (issue #1397).
  String _locate(String recorded) =>
      normalizeArtifactPath(resolvedProjectRoot, recorded);

  /// The persisted form of [record] (issue #1397): both artifact paths in
  /// the portable project-relative POSIX form, and — when the runnable
  /// name's first `::` segment names the test path — that segment rebuilt
  /// with the persisted form. Every later segment (id, description) is
  /// preserved verbatim so description extraction keeps parsing the same
  /// name.
  ArtifactRecord _canonicalize(ArtifactRecord record) {
    final testPath = canonicalArtifactPath(
      resolvedProjectRoot,
      record.testPath,
    );
    final subjectPath = canonicalArtifactPath(
      resolvedProjectRoot,
      record.subjectPath,
    );
    if (testPath == record.testPath && subjectPath == record.subjectPath) {
      return record;
    }
    final segments = record.runnableTestName.split('::');
    final firstIsTestPath =
        segments.isNotEmpty &&
        (segments.first == record.testPath ||
            p.equals(
              normalizeArtifactPath(resolvedProjectRoot, segments.first),
              normalizeArtifactPath(resolvedProjectRoot, record.testPath),
            ));
    final runnableTestName = firstIsTestPath
        ? (segments.length == 1
              ? testPath
              : '$testPath::${segments.skip(1).join('::')}')
        : record.runnableTestName;
    return ArtifactRecord(
      behaviorId: record.behaviorId,
      feature: record.feature,
      sourceCriterion: record.sourceCriterion,
      testPath: testPath,
      subjectPath: subjectPath,
      runnableTestName: runnableTestName,
      testOwnership: record.testOwnership,
      subjectOwnership: record.subjectOwnership,
      createdAt: record.createdAt,
    );
  }

  /// Bug #827 migration hint: when one of the two mismatched paths is the
  /// legacy flat gen layout (`test/tdd/<file>` / `lib/tdd/<file>`) and the
  /// other is its namespaced successor, name the migration command instead
  /// of leaving the conflict unexplained.
  static String _legacyHint(String priorPath, String recordPath) {
    const legacyRoots = {'test/tdd', 'lib/tdd'};
    bool isLegacyFlat(String path) {
      final normalized = p.normalize(path).replaceAll(r'\', '/');
      final dir = p.dirname(normalized);
      return legacyRoots.contains(dir) ||
          dir.endsWith('/test/tdd') ||
          dir.endsWith('/lib/tdd');
    }

    final sameFile = p.basename(priorPath) == p.basename(recordPath);
    if (sameFile &&
        (isLegacyFlat(priorPath) || isLegacyFlat(recordPath)) &&
        isLegacyFlat(priorPath) != isLegacyFlat(recordPath)) {
      return ' (legacy flat layout detected — run `zfa tdd migrate-paths` '
          'to move this feature\'s artifacts to the per-feature namespaced '
          'layout)';
    }
    return '';
  }
}
