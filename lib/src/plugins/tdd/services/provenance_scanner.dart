/// `ProvenanceScanner` — attributes every file under the driven app's
/// `lib/` to a recorded zfa command invocation (spec 051-corpus-harness,
/// FR-005/FR-006): the loop's artifact registries, cycle-log refactor
/// evidence, setup/import provenance records, and the carve-out manifest
/// — the audit's proof sources, in that priority order.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Where an attribution came from (scan priority order).
enum AttributionSource { registry, refactor, provenance, carveout }

/// One file's attribution: the recorded invocation it traces to.
class Attribution {
  const Attribution({required this.source, required this.command});

  final AttributionSource source;

  /// The zfa invocation (or carve-out reason) the file traces to.
  final String command;
}

/// Scan counts for the machine report.
class ProvenanceCounts {
  const ProvenanceCounts({
    required this.files,
    required this.attributed,
    required this.carveout,
    required this.unattributed,
  });

  final int files;
  final int attributed;
  final int carveout;
  final int unattributed;
}

/// The scan result: per-file attributions (POSIX project-relative keys),
/// unattributed files by name, and the counts.
class ProvenanceReport {
  ProvenanceReport({
    required Map<String, Attribution> attributedFiles,
    required this.unattributed,
    required int totalFiles,
  }) : files = attributedFiles,
       counts = ProvenanceCounts(
         files: totalFiles,
         // Three separate buckets (US3): attributed = traced to a zfa
         // invocation; carveout = exempted by the manifest; the rest
         // unattributed. attributed + carveout + unattributed == files.
         attributed: attributedFiles.length -
             attributedFiles.values
                 .where((a) => a.source == AttributionSource.carveout)
                 .length,
         carveout: attributedFiles.values
             .where((a) => a.source == AttributionSource.carveout)
             .length,
         unattributed: unattributed.length,
       );

  /// Every attributed `lib/` file (relative path) -> its attribution.
  final Map<String, Attribution> files;

  /// Unattributed files, by name (the audit failures).
  final List<String> unattributed;

  final ProvenanceCounts counts;

  Attribution? attributed(String relPath) => files[relPath];
}

class ProvenanceScanner {
  ProvenanceScanner(this.projectRoot);

  /// The driven app's project root.
  final String projectRoot;

  /// Walk `lib/` and attribute every file (FR-005). Attribution sources,
  /// in priority order: artifact registries (`specs/*/tdd/artifacts.json`
  /// subject_path), cycle-log refactor `changed:` lists, setup/import
  /// provenance records (`.zfa/provenance/*.json`), and the carve-out
  /// manifest. Malformed source rows are skipped (the audit reports the
  /// files, not the broken evidence); a broken source file never crashes
  /// the scan.
  Future<ProvenanceReport> scan() async {
    final files = <String, Attribution>{};

    // --- The lib/ walk (the audit's scope). ---
    final libDir = Directory(p.join(projectRoot, 'lib'));
    final libFiles = <String>[];
    if (await libDir.exists()) {
      await for (final entity in libDir.list(recursive: true)) {
        if (entity is File) {
          libFiles.add(p.relative(entity.path, from: projectRoot));
        }
      }
    }
    libFiles.sort();

    // --- Source 1: artifact registries (subject_path). ---
    await _collectRegistryAttributions(files);
    // --- Source 2: cycle-log refactor changed lists. ---
    await _collectRefactorAttributions(files);
    // --- Source 3: setup/import provenance records. ---
    await _collectProvenanceAttributions(files);
    // --- Source 4: the carve-out manifest (the sole exemption path). ---
    await _collectCarveOutAttributions(files);

    final unattributed = libFiles
        .where((f) => files[f] == null)
        .toList();
    return ProvenanceReport(
      attributedFiles: {
        for (final f in libFiles)
          if (files[f] != null) f: files[f]!,
      },
      unattributed: unattributed,
      totalFiles: libFiles.length,
    );
  }

  /// `specs/*/tdd/artifacts.json`: every record's `subject_path`
  /// attributes to that feature's loop invocation.
  Future<void> _collectRegistryAttributions(
    Map<String, Attribution> files,
  ) async {
    final specsDir = Directory(p.join(projectRoot, 'specs'));
    if (!await specsDir.exists()) return;
    await for (final featureDir in specsDir.list()) {
      if (featureDir is! Directory) continue;
      final registry = File(
        p.join(featureDir.path, 'tdd', 'artifacts.json'),
      );
      if (!await registry.exists()) continue;
      try {
        final decoded = jsonDecode(await registry.readAsString());
        if (decoded is! Map) continue;
        final records = decoded['records'];
        if (records is! List) continue;
        for (final record in records) {
          if (record is! Map) continue;
          final subject = record['subject_path'];
          if (subject is! String || subject.isEmpty) continue;
          final behavior = record['behavior_id'];
          final feature = record['feature'];
          final rel = normalize(subject);
          if (!rel.startsWith('lib/')) continue;
          files.putIfAbsent(
            rel,
            () => Attribution(
              source: AttributionSource.registry,
              command:
                  'zfa tdd gen ${behavior is String ? behavior : '?'}/loop'
                  ' (feature ${feature is String ? feature : p.basename(featureDir.path)}, artifacts.json)',
            ),
          );
        }
      } on FormatException {
        // A broken registry is reported evidence, not a crash (the file
        // stays unattributed unless another source covers it).
        continue;
      }
    }
  }

  /// `specs/*/tdd/cycle-log.md`: refactor entries' `actions:` blocks and
  /// their `changed:` file lists attribute to the recorded command.
  Future<void> _collectRefactorAttributions(
    Map<String, Attribution> files,
  ) async {
    final specsDir = Directory(p.join(projectRoot, 'specs'));
    if (!await specsDir.exists()) return;
    await for (final featureDir in specsDir.list()) {
      if (featureDir is! Directory) continue;
      final cycleLog = File(p.join(featureDir.path, 'tdd', 'cycle-log.md'));
      if (!await cycleLog.exists()) continue;
      final lines = (await cycleLog.readAsString()).split('\n');
      var inRefactorSection = false;
      var currentCommand = p.basename(featureDir.path);
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('## Cycle:')) {
          inRefactorSection = trimmed.endsWith('(refactor)');
          continue;
        }
        if (trimmed.startsWith('command: `') && trimmed.endsWith('`')) {
          currentCommand = trimmed.substring(
            'command: `'.length,
            trimmed.length - 1,
          );
          continue;
        }
        if (inRefactorSection && trimmed.startsWith('changed:')) {
          final list = trimmed.substring('changed:'.length).trim();
          for (final raw in list.split(',')) {
            final candidate = raw.trim();
            if (candidate.isEmpty || candidate == '(none)') continue;
            final rel = normalize(candidate);
            if (!rel.startsWith('lib/')) continue;
            files.putIfAbsent(
              rel,
              () => Attribution(
                source: AttributionSource.refactor,
                command: currentCommand,
              ),
            );
          }
        }
      }
    }
  }

  /// `.zfa/provenance/*.json`: `{command, at?, files: [...]}` records in
  /// single-object or array form (the #626/#627 emission contract).
  Future<void> _collectProvenanceAttributions(
    Map<String, Attribution> files,
  ) async {
    final dir = Directory(p.join(projectRoot, '.zfa', 'provenance'));
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      try {
        final decoded = jsonDecode(await entity.readAsString());
        final records = decoded is List ? decoded : [decoded];
        for (final record in records) {
          if (record is! Map) continue;
          final command = record['command'];
          if (command is! String || command.isEmpty) continue;
          final fileList = record['files'];
          if (fileList is! List) continue;
          for (final raw in fileList) {
            if (raw is! String || raw.isEmpty) continue;
            final rel = normalize(raw);
            if (!rel.startsWith('lib/')) continue;
            files.putIfAbsent(
              rel,
              () => Attribution(
                source: AttributionSource.provenance,
                command: command,
              ),
            );
          }
        }
      } on FormatException {
        continue;
      }
    }
  }

  /// `.zfa/manifests/corpus-carveout.json`: the sole exemption path.
  Future<void> _collectCarveOutAttributions(
    Map<String, Attribution> files,
  ) async {
    final file = File(
      p.join(projectRoot, '.zfa', 'manifests', 'corpus-carveout.json'),
    );
    if (!await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return;
      final carveouts = decoded['carveouts'];
      if (carveouts is! List) return;
      for (final entry in carveouts) {
        if (entry is! Map) continue;
        final path = entry['path'];
        final reason = entry['reason'];
        if (path is! String || path.isEmpty || reason is! String) continue;
        final rel = normalize(path);
        if (!rel.startsWith('lib/')) continue;
        files.putIfAbsent(
          rel,
          () => Attribution(
            source: AttributionSource.carveout,
            command: 'carve-out: $reason',
          ),
        );
      }
    } on FormatException {
      return;
    }
  }

  /// Normalize a recorded path to a POSIX project-relative form.
  String normalize(String recorded) {
    var path = recorded;
    if (p.isAbsolute(path)) {
      path = p.relative(path, from: projectRoot);
    }
    path = p.posix.normalize(path);
    return path;
  }
}
