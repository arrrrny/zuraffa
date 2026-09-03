/// `PassRegistryTracker` — persists the pass-registry-changed files of
/// each `zfa tdd refactor` application and maps them to their covering
/// tests (spec 069-corpus-economics, T001 — incremental verification).
///
/// The refactor re-proof previously re-ran the FULL suite after every
/// pass application (the 9m30s "ONE refactor" cost in issue #916). The
/// incremental contract scopes that re-proof to the tests that COVER the
/// pass-registry-changed files, resolved through the feature's artifact
/// registry (`gen`'s subject↔test pairing — never a glob, mirroring
/// verify-red's FR-001):
///
/// - every changed file must BE a registered artifact's subject (the
///   FR-005 attribution check already guarantees every changed `lib/`
///   path was touched by a recorded pass action; the registry then
///   proves which behavior it belongs to);
/// - one unattributable file poisons the whole set → EMPTY covering
///   set → the caller falls back to the FULL suite (safe failure —
///   never a silently narrowed re-proof, mirroring RunBaselineCache's
///   U18/#741 stance);
/// - the full gate still exists, frequency engineered: the full suite
///   runs at feature completion (`zfa tdd verify`'s preflight) and
///   nightly (the corpus lane), and on demand via
///   `zfa tdd refactor --full-reproof`.
///
/// The change registry lives at `specs/<feature>/tdd/pass-registry.json`
/// and is append-only across refactor applications (each entry carries
/// the files a single application changed, the command, and the capture
/// time). Reading is fail-safe: missing, corrupt, or wrong-schema files
/// yield null — the caller then re-derives from the live pass result.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/artifact_record.dart';

/// One recorded refactor application's changed-file set.
class PassRegistryEntry {
  const PassRegistryEntry({
    required this.files,
    required this.capturedAt,
    this.command,
  });

  /// The `lib/` files this application changed (relative to the project
  /// root, forward slashes — the TreeSnapshot contract).
  final List<String> files;

  /// ISO-8601 capture time.
  final String capturedAt;

  /// The pass command that produced the change (diagnostics only).
  final String? command;

  Map<String, dynamic> toJson() => {
    'files': files.toList(),
    'captured_at': capturedAt,
    if (command != null) 'command': command,
  };

  static PassRegistryEntry? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final files = json['files'];
    final capturedAt = json['captured_at'];
    if (files is! List || capturedAt is! String) return null;
    final fileNames = files.whereType<String>().toList();
    final command = json['command'];
    return PassRegistryEntry(
      files: fileNames,
      capturedAt: capturedAt,
      command: command is String ? command : null,
    );
  }
}

/// The parsed pass-registry.json snapshot.
class PassRegistrySnapshot {
  const PassRegistrySnapshot({required this.entries});

  final List<PassRegistryEntry> entries;

  /// The union of changed files across every recorded application.
  Set<String> unionChangedFiles() => entries.expand((e) => e.files).toSet();
}

class PassRegistryTracker {
  const PassRegistryTracker({required this.featureDir});

  /// Absolute path to the feature's spec directory
  /// (e.g. `/repo/specs/048-tdd-refactor`).
  final String featureDir;

  /// The registry file name inside the feature's `tdd/` directory.
  static const fileName = 'pass-registry.json';

  /// The registry path for a feature directory.
  static String pathFor({required String featureDir}) =>
      p.join(featureDir, 'tdd', fileName);

  /// Append one refactor application's changed-file set. A corrupt or
  /// wrong-schema existing file is REPLACED (the registry is derived
  /// data, recomputed by every refactor application — unlike the cycle
  /// log it is not primary evidence; the cycle-log entry remains the
  /// tamper-evident record).
  Future<String> record({
    required List<String> changedFiles,
    required String capturedAt,
    String? command,
  }) async {
    final file = File(pathFor(featureDir: featureDir));
    await file.parent.create(recursive: true);
    final existing = await read(file.path);
    final entries = [
      ...?existing?.entries,
      if (changedFiles.isNotEmpty)
        PassRegistryEntry(
          files: changedFiles.toList(),
          capturedAt: capturedAt,
          command: command,
        ),
    ];
    await file.writeAsString(
      jsonEncode({
        'entries': [for (final e in entries) e.toJson()],
      }),
    );
    return file.path;
  }

  /// Load a registry snapshot. Returns null when the file is missing,
  /// unreadable, corrupt, or typed wrong — the caller falls back to the
  /// live pass result (safe failure).
  static Future<PassRegistrySnapshot?> read(String path) async {
    try {
      final raw = await File(path).readAsString();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final rawEntries = json['entries'];
      if (rawEntries is! List) return null;
      final entries = <PassRegistryEntry>[];
      for (final e in rawEntries) {
        final entry = PassRegistryEntry.fromJson(e);
        if (entry == null) return null;
        entries.add(entry);
      }
      return PassRegistrySnapshot(entries: entries);
    } catch (_) {
      return null;
    }
  }

  /// The covering TESTS for [changedFiles] through [artifacts] (the
  /// feature's registered gen pairs).
  ///
  /// Every changed file must be a registered artifact's subject path
  /// (normalized against [projectRoot]: the registry stores absolute
  /// paths, the tree snapshot stores project-relative ones). One
  /// unattributable file → the empty set (the full-suite fallback
  /// signal — never a silently narrowed re-proof).
  static Set<String> coveringTestsFor({
    required Set<String> changedFiles,
    required List<ArtifactRecord> artifacts,
    required String projectRoot,
  }) {
    if (changedFiles.isEmpty) return const {};
    // subject path (normalized, posix) -> covering test path.
    final subjectToTest = <String, String>{};
    for (final record in artifacts) {
      final subject = _normalize(record.subjectPath, projectRoot);
      final test = _normalize(record.testPath, projectRoot);
      subjectToTest[subject] = test;
    }
    final covering = <String>{};
    for (final changed in changedFiles) {
      final normalized = _normalize(changed, projectRoot);
      final test = subjectToTest[normalized];
      if (test == null) return const {}; // unattributable — full gate.
      covering.add(test);
    }
    return covering;
  }

  /// Normalize a path to a project-relative, forward-slashed form for
  /// comparison (absolute paths are made relative to [projectRoot];
  /// already-relative paths pass through).
  static String _normalize(String path, String projectRoot) {
    var normalized = p.normalize(path);
    if (p.isAbsolute(normalized)) {
      normalized = p.relative(normalized, from: p.normalize(projectRoot));
    }
    return p.posix.normalize(normalized);
  }
}
