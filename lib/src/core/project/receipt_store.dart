import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Proof-carrying generation (issue #807).
///
/// A [GenerationReceipt] is the verifiable record a generator ships with
/// every artifact it writes: which command produced it, from which spec,
/// with which input context, and the digest of the exact bytes that landed
/// on disk. `zfa proof check` re-derives every digest and fails on any
/// artifact that cannot prove where it came from.
///
/// Receipts live in `.zfa/receipts/` as one JSON document per generation
/// run (schema `proof.v1`).

/// Digest binding for a single file a generation run wrote.
class GenerationReceiptFile {
  /// Project-relative POSIX path of the artifact.
  final String path;

  /// What the run did to it: `create`, `update`/`modify` or `delete`.
  final String action;

  /// SHA-256 (hex) of the artifact's final on-disk bytes.
  final String sha256;

  final int bytes;

  /// Final text content when the artifact is small enough to keep a
  /// snapshot ([ReceiptStore.maxSnapshotBytes]); enables precise line
  /// diffs on drift instead of a bare digest mismatch.
  final String? snapshot;

  const GenerationReceiptFile({
    required this.path,
    required this.action,
    required this.sha256,
    required this.bytes,
    this.snapshot,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    'action': action,
    'sha256': sha256,
    'bytes': bytes,
    if (snapshot != null) 'snapshot': snapshot,
  };

  factory GenerationReceiptFile.fromJson(Map<String, dynamic> json) =>
      GenerationReceiptFile(
        path: json['path'] as String,
        action: json['action'] as String? ?? 'create',
        sha256: json['sha256'] as String,
        bytes: json['bytes'] as int? ?? 0,
        snapshot: json['snapshot'] as String?,
      );
}

/// Digest binding to the spec an artifact was generated FROM (e.g. the
/// entity source a `make` run consumed). If the spec changes afterwards,
/// the artifact is stale and `zfa proof check` names the exact delta.
class GenerationReceiptSpec {
  /// Project-relative POSIX path of the spec file.
  final String path;

  /// SHA-256 (hex) of the spec bytes at generation time.
  final String sha256;

  /// Spec content snapshot (same cap as artifact snapshots).
  final String? snapshot;

  const GenerationReceiptSpec({
    required this.path,
    required this.sha256,
    this.snapshot,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    'sha256': sha256,
    if (snapshot != null) 'snapshot': snapshot,
  };

  factory GenerationReceiptSpec.fromJson(Map<String, dynamic> json) =>
      GenerationReceiptSpec(
        path: json['path'] as String,
        sha256: json['sha256'] as String,
        snapshot: json['snapshot'] as String?,
      );
}

/// One generation run's proof record (schema `proof.v1`).
class GenerationReceipt {
  final String schema;
  final String command;

  /// What the run was about, usually the entity name (`Product`).
  final String target;

  /// One-line command a human/agent can paste to reproduce this run.
  final String repro;
  final DateTime at;

  /// Generator/template version that produced the artifacts.
  final String generatorVersion;

  /// Input context the run consumed (flags, fields, plugin ids, ...).
  final Map<String, dynamic> input;

  /// The spec this run consumed, when one exists.
  final GenerationReceiptSpec? spec;
  final List<GenerationReceiptFile> files;

  const GenerationReceipt({
    this.schema = 'proof.v1',
    required this.command,
    required this.target,
    required this.repro,
    required this.at,
    required this.generatorVersion,
    required this.input,
    this.spec,
    required this.files,
  });

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'command': command,
    'target': target,
    'repro': repro,
    'at': at.toUtc().toIso8601String(),
    'generator_version': generatorVersion,
    'input': input,
    if (spec != null) 'spec': spec!.toJson(),
    'files': files.map((f) => f.toJson()).toList(),
  };

  factory GenerationReceipt.fromJson(Map<String, dynamic> json) =>
      GenerationReceipt(
        schema: json['schema'] as String? ?? 'proof.v1',
        command: json['command'] as String,
        target: json['target'] as String? ?? '',
        repro: json['repro'] as String? ?? '',
        at: DateTime.parse(json['at'] as String),
        generatorVersion: json['generator_version'] as String? ?? '',
        input: json['input'] is Map
            ? Map<String, dynamic>.from(json['input'] as Map)
            : const <String, dynamic>{},
        spec: json['spec'] is Map
            ? GenerationReceiptSpec.fromJson(
                Map<String, dynamic>.from(json['spec'] as Map),
              )
            : null,
        files: (json['files'] as List? ?? const [])
            .map(
              (f) => GenerationReceiptFile.fromJson(
                Map<String, dynamic>.from(f as Map),
              ),
            )
            .toList(growable: false),
      );
}

/// A receipt as loaded from disk, with the file name it came from.
class ReceiptRecord {
  final String fileName;
  final GenerationReceipt receipt;

  const ReceiptRecord({required this.fileName, required this.receipt});
}

/// Reads and writes generation receipts under `<project>/.zfa/receipts/`.
class ReceiptStore {
  final String projectRoot;

  /// Artifacts at or below this size keep a content snapshot in their
  /// receipt so drift can be reported as a precise line diff. Larger
  /// artifacts verify by digest only.
  static const int maxSnapshotBytes = 16 * 1024;

  const ReceiptStore({required this.projectRoot});

  Directory get directory => Directory(p.join(projectRoot, '.zfa', 'receipts'));

  /// Persists [receipt] as a timestamped JSON document; returns the file.
  Future<File> save(GenerationReceipt receipt) async {
    await directory.create(recursive: true);
    // Colons are illegal in Windows file names; keep every name portable.
    final stamp = receipt.at.toUtc().toIso8601String().replaceAll(':', '-');
    final cmd = _sanitize(receipt.command);
    final target = _sanitize(receipt.target);
    final file = File(p.join(directory.path, '$stamp-$cmd-$target.json'));
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(receipt.toJson()));
    return file;
  }

  /// Loads every parseable receipt, oldest first (ties broken by file
  /// name so latest-wins indexing is deterministic). Corrupted documents
  /// are skipped, not fatal — one broken receipt must not erase the
  /// provenance of every healthy artifact.
  ///
  /// Spec 980: `test-*.json` documents are the test plugin's `test.v1`
  /// per-method receipts — a separate document kind parsed by
  /// [TestReceiptStore] — and are deliberately skipped here.
  Future<List<ReceiptRecord>> loadAll() async {
    if (!directory.existsSync()) return const [];
    final files =
        directory
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .where((f) => !p.basename(f.path).startsWith('test-'))
            .toList()
          ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    final records = <ReceiptRecord>[];
    for (final file in files) {
      try {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        records.add(
          ReceiptRecord(
            fileName: p.basename(file.path),
            receipt: GenerationReceipt.fromJson(json),
          ),
        );
      } catch (_) {
        // Skip corrupted receipts.
      }
    }
    records.sort((a, b) {
      final byTime = a.receipt.at.compareTo(b.receipt.at);
      return byTime != 0 ? byTime : a.fileName.compareTo(b.fileName);
    });
    return records;
  }

  /// The most recent receipt entry covering [path], or null when the path
  /// is unprovenanced. [records] must be oldest-first (see [loadAll]).
  static ({ReceiptRecord record, GenerationReceiptFile entry})? latestForPath(
    List<ReceiptRecord> records,
    String path,
  ) {
    ({ReceiptRecord record, GenerationReceiptFile entry})? latest;
    for (final record in records) {
      for (final entry in record.receipt.files) {
        if (entry.path == path) latest = (record: record, entry: entry);
      }
    }
    return latest;
  }

  static String _sanitize(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
}
