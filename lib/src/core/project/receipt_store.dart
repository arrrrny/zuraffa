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

  /// Plugin id of the standalone capability that produced this run
  /// (issue #996): `di`, `cache`, `usecase`, ... Null for make-path
  /// receipts, which predate the capability provenance fields.
  final String? plugin;

  /// Capability name of the standalone invocation (issue #996): `create`
  /// for `zfa di create`, `adapter` for `zfa cache adapter`, `enable`
  /// for `zfa sync enable`, the layout for `zfa shadcn <layout>`.
  final String? capability;

  /// The entity the capability operated on (issue #996).
  final String? entity;

  /// The methodset the invocation wired (issue #996) — e.g. the
  /// `--methods` list `zfa di create Product --methods get,update` wired.
  /// Empty but non-null on capability receipts that wire no methods.
  final List<String>? methodset;

  /// SHA-256 run digest (issue #996 `hash`): binds the entity, the
  /// methodset and every per-file `(path, action, sha256)` tuple the
  /// run committed. Re-derivable from the receipt itself.
  final String? runHash;

  /// Machine schema version of the receipt envelope (issue #996
  /// `receipt_version`). 1 for both capability and make-path receipts.
  final int receiptVersion;

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
    this.plugin,
    this.capability,
    this.entity,
    this.methodset,
    this.runHash,
    this.receiptVersion = 1,
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
    if (plugin != null) 'plugin': plugin,
    if (capability != null) 'capability': capability,
    if (entity != null) 'entity': entity,
    if (methodset != null) 'methodset': methodset,
    if (runHash != null) 'hash': runHash,
    'receipt_version': receiptVersion,
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
        plugin: json['plugin'] as String?,
        capability: json['capability'] as String?,
        entity: json['entity'] as String?,
        methodset: (json['methodset'] as List?)
            ?.map((m) => m.toString())
            .toList(growable: false),
        runHash: json['hash'] as String?,
        receiptVersion: json['receipt_version'] as int? ?? 1,
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

  /// Persists [receipt] as a JSON document; returns the file.
  ///
  /// By default the document is timestamped (`$stamp-$cmd-$target.json`).
  /// When [fileName] is provided (spec #977: standalone plugin receipts
  /// such as `datasource-<entity>.json`), that name is used instead —
  /// sanitized the same way, with a `.json` suffix ensured. `loadAll`
  /// picks up both naming schemes, so `zfa proof check` verifies either.
  Future<File> save(GenerationReceipt receipt, {String? fileName}) async {
    await directory.create(recursive: true);
    final String resolvedName;
    if (fileName != null) {
      final base = fileName.replaceAll(RegExp(r'\.json$'), '');
      resolvedName = '${_sanitize(base)}.json';
    } else {
      // Colons are illegal in Windows file names; keep every name portable.
      final stamp = receipt.at.toUtc().toIso8601String().replaceAll(':', '-');
      final cmd = _sanitize(receipt.command);
      final target = _sanitize(receipt.target);
      resolvedName = '$stamp-$cmd-$target.json';
    }
    final file = File(p.join(directory.path, resolvedName));
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(receipt.toJson()));
    return file;
  }

  /// Persists a standalone capability receipt (issue #996) keyed
  /// `<plugin>-<capability>-<entity>-<timestamp>.json`. Same portable
  /// naming rules as [save]; the key shape is the machine contract the
  /// issue pins, so agents can predict the file from the invocation.
  Future<File> saveCapability(GenerationReceipt receipt) async {
    await directory.create(recursive: true);
    final stamp = receipt.at.toUtc().toIso8601String().replaceAll(':', '-');
    final plugin = _sanitize(receipt.plugin ?? receipt.command);
    final capability = _sanitize(receipt.capability ?? 'capability');
    final entity = _sanitize(receipt.entity ?? receipt.target);
    final file = File(
      p.join(directory.path, '$plugin-$capability-$entity-$stamp.json'),
    );
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(receipt.toJson()));
    return file;
  }

  /// Persists [receipt] under an explicit [fileName] (issue #970): the
  /// mock-certification receipts use the stable per-entity name
  /// `mock-<entity>.json` so a regeneration supersedes the previous proof
  /// for that entity (the checker's latest-wins contract) instead of
  /// accumulating timestamped duplicates per run.
  Future<File> saveAs(String fileName, GenerationReceipt receipt) async {
    await directory.create(recursive: true);
    final base = _sanitize(fileName.replaceAll('.json', ''));
    final file = File(p.join(directory.path, '$base.json'));
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(receipt.toJson()));
    return file;
  }

  /// Persists [receipt] at a DETERMINISTIC path ([fileName], sanitized)
  /// instead of the timestamped run-scoped name, so a later consumer can
  /// find the latest state by name — e.g. the #963 route-coverage ledger
  /// reads `.zfa/receipts/routes-<entity>.json` (issue #971 order 3),
  /// spec #979 provider receipts use `provider-<entity>.json`, and spec
  /// #970 mock-certification receipts use `mock-<entity>.json`.
  ///
  /// Stable names make a receipt addressable per entity (the verify gates
  /// and ledgers read them by path) instead of by timestamp scanning, and
  /// regeneration supersedes the previous document in place (last write
  /// wins — `loadAll` still sees exactly one current document per artifact
  /// set). [extra] fields are merged into the document on top of the
  /// proof.v1 payload: [GenerationReceipt.fromJson] ignores unknown keys,
  /// so the document stays a parseable generation receipt for [loadAll]
  /// and `zfa proof check` while carrying plugin-specific ledger data
  /// (interface, methods, stub count) without forking the proof.v1 schema.
  Future<File> saveNamed(
    String fileName,
    GenerationReceipt receipt, {
    Map<String, dynamic> extra = const {},
  }) async {
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, _sanitize(fileName)));
    const encoder = JsonEncoder.withIndent('  ');
    final payload = <String, dynamic>{...receipt.toJson(), ...extra};
    await file.writeAsString(encoder.convert(payload));
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
