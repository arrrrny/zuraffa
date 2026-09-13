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

/// Raised when `tdd/artifacts.json` exists but cannot be parsed (issue
/// #1470). A corrupt registry is NOT a fresh feature: treating it as one
/// makes `register` re-emit artifacts with [Ownership.created] and the
/// next append rewrite the file, silently destroying the prior records.
/// The message names the file and the recovery path — the same contract
/// as `RunStateCorruptException`.
class ArtifactRegistryCorruptException implements Exception {
  const ArtifactRegistryCorruptException(this.message);

  final String message;

  @override
  String toString() => message;
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

  /// The project root recorded artifact paths resolve against (issue
  /// #1397): alias of [projectRoot] — the standard TDD layout anchors
  /// every feature directory at `<projectRoot>/specs/<feature>`. Relative
  /// recorded paths must NEVER resolve against the process CWD: the CLI
  /// can run from anywhere.
  String get resolvedProjectRoot => projectRoot;

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
  /// [reanchor] defaults to true (#1357): stale absolute paths resolve to
  /// their repo-relative lane suffix so every reader sees a runnable view.
  /// The form-repair commands (doctor, migrate-paths) load with
  /// `reanchor: false` — they must see the RAW stored forms or the
  /// reanchored view masks the very drift they detect and repair
  /// (issue #1397 x #1357).
  Future<List<ArtifactRecord>> loadAll({bool reanchor = true}) async {
    return _loadRecords(reanchor: reanchor);
  }

  /// Find a single record by behavior id. Returns `null` if not found.
  Future<ArtifactRecord?> findRecord(String behaviorId) async {
    final records = await _loadRecords();
    for (final r in records) {
      if (r.behaviorId == behaviorId) return r;
    }
    return null;
  }

  Future<List<ArtifactRecord>> _loadRecords({bool reanchor = true}) async {
    final file = File(registryPath);
    if (!await file.exists()) return [];
    try {
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final records = (raw['records'] as List?) ?? [];
      return records.map((r) {
        final record = ArtifactRecord.fromJson(r as Map<String, dynamic>);
        return reanchor ? _reanchorRecord(record) : record;
      }).toList();
    } on FormatException catch (e) {
      // Issue #1470: a corrupt registry must NOT read as "no prior
      // records" — register() would re-emit artifacts with
      // Ownership.created and the next append rewrite the file, silently
      // destroying every prior record. Fail loud instead, the way
      // RunStateStore does for run-state.json: name the file and the
      // recovery path. (A MISSING file stays the legitimate empty
      // registry of a fresh feature — FR-012 — see the exists() guard
      // above, which this does not touch.)
      throw ArtifactRegistryCorruptException(
        'Corrupt artifacts.json at $registryPath: ${e.message}. '
        'Delete the file and re-run gen to rebuild the registry.',
      );
    }
  }

  /// Issue #1357: a registry written in sandbox A is otherwise
  /// unrunnable in every environment B≠A — the fuzz preflight's "the
  /// tests never ran" forever. Re-anchor stale absolute paths to the
  /// repo-relative lane suffix when one exists under the project root.
  ArtifactRecord _reanchorRecord(ArtifactRecord record) {
    final testPath = reanchorRecordPath(record.testPath, projectRoot);
    final subjectPath = reanchorRecordPath(record.subjectPath, projectRoot);
    var runnable = record.runnableTestName;
    final separator = runnable.indexOf('::');
    if (separator > 0) {
      final pathPart = runnable.substring(0, separator);
      final reanchored = reanchorRecordPath(pathPart, projectRoot);
      runnable = '$reanchored${runnable.substring(separator)}';
    }
    return ArtifactRecord(
      behaviorId: record.behaviorId,
      feature: record.feature,
      sourceCriterion: record.sourceCriterion,
      testPath: testPath,
      subjectPath: subjectPath,
      runnableTestName: runnable,
      testOwnership: record.testOwnership,
      subjectOwnership: record.subjectOwnership,
      createdAt: record.createdAt,
    );
  }

  /// The project root this registry's feature lives under
  /// (`<root>/specs/<feature>`); lanes (`test/`, `lib/`) hang off it.
  String get projectRoot {
    final absolute = p.isAbsolute(featureDir)
        ? featureDir
        : p.absolute(featureDir);
    // `<root>/specs/<feature>`; fall back to the immediate parent for
    // layouts that do not nest under a `specs/` directory.
    final parent = p.dirname(absolute);
    return p.basename(parent) == 'specs'
        ? p.dirname(parent)
        : p.dirname(absolute);
  }

  /// Re-anchors [stored] to a repo-relative path when it is an absolute
  /// path that does not exist as-is but whose suffix starting at the
  /// last `/test/` or `/lib/` lane marker exists under [projectRoot].
  /// Relative paths, existing absolutes, and unresolvable absolutes are
  /// returned verbatim (never invent a path).
  // ignore: avoid_public_member_api_docs
  static String reanchorRecordPath(String stored, String projectRoot) {
    if (stored.isEmpty) return stored;
    final normalized = stored.replaceAll(r'\', '/');
    if (!p.isAbsolute(normalized)) return normalized;
    if (File(normalized).existsSync()) return normalized;
    for (final marker in ['/test/', '/lib/']) {
      final index = normalized.lastIndexOf(marker);
      if (index < 0) continue;
      final candidate = normalized.substring(index + 1);
      if (File(p.join(projectRoot, candidate)).existsSync()) {
        return candidate;
      }
    }
    return normalized;
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
