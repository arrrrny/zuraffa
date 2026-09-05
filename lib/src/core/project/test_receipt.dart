import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

/// Spec 980 / FR-003 — per-method test receipts.
///
/// A [TestReceipt] is the test plugin's proof record: it maps every
/// generated test to the usecase method it exercises, the acceptance path
/// it covers (success / failure), and the SHA-256 digests of the test file
/// and the usecase source it was generated against. `zfa proof check`
/// re-derives the digests and flags usecase/test drift when the usecase
/// changed after the tests were generated.
///
/// Receipts live in `.zfa/receipts/` as `test-<entity>.json` (schema
/// `test.v1`) — a sibling of, but distinct from, the timestamped `proof.v1`
/// [GenerationReceipt] documents.

/// One generated test bound to its usecase method + acceptance path.
class TestReceiptEntry {
  /// Human name of the `test('...')` block, exactly as generated.
  final String name;

  /// Project-relative POSIX path of the generated test file.
  final String testPath;

  /// Use case method under test (`get`, `create`, …; `execute` for
  /// custom/orchestrator/polymorphic usecases).
  final String method;

  /// Covered acceptance path: `success` or `failure`.
  final String acceptancePath;

  /// SHA-256 (hex) of the test file's bytes at generation time.
  final String testSha256;

  /// Project-relative POSIX path of the usecase source the test covers.
  final String? useCasePath;

  /// SHA-256 (hex) of the usecase source at generation time. Drift between
  /// this and the current file is the usecase/test drift signal.
  final String? useCaseSha256;

  const TestReceiptEntry({
    required this.name,
    required this.testPath,
    required this.method,
    required this.acceptancePath,
    required this.testSha256,
    this.useCasePath,
    this.useCaseSha256,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'test_path': testPath,
    'method': method,
    'acceptance_path': acceptancePath,
    'test_sha256': testSha256,
    if (useCasePath != null) 'usecase_path': useCasePath,
    if (useCaseSha256 != null) 'usecase_sha256': useCaseSha256,
  };

  factory TestReceiptEntry.fromJson(Map<String, dynamic> json) =>
      TestReceiptEntry(
        name: json['name'] as String,
        testPath: json['test_path'] as String,
        method: json['method'] as String? ?? 'execute',
        acceptancePath: json['acceptance_path'] as String? ?? 'success',
        testSha256: json['test_sha256'] as String,
        useCasePath: json['usecase_path'] as String?,
        useCaseSha256: json['usecase_sha256'] as String?,
      );
}

/// One entity's per-method test receipt (schema `test.v1`).
class TestReceipt {
  static const String schemaName = 'test.v1';

  /// Entity (or usecase target) the tests were generated for.
  final String entity;

  /// One-line command a human/agent can paste to reproduce this run.
  final String command;

  final DateTime at;

  /// One entry per generated test block, in generation order.
  final List<TestReceiptEntry> tests;

  const TestReceipt({
    required this.entity,
    required this.command,
    required this.at,
    required this.tests,
  });

  /// Document kind of this receipt (`test.v1`).
  String get schema => schemaName;

  Map<String, dynamic> toJson() => {
    'schema': schemaName,
    'entity': entity,
    'command': command,
    'at': at.toUtc().toIso8601String(),
    'tests': tests.map((t) => t.toJson()).toList(),
  };

  factory TestReceipt.fromJson(Map<String, dynamic> json) => TestReceipt(
    entity: json['entity'] as String,
    command: json['command'] as String? ?? '',
    at:
        DateTime.tryParse(json['at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    tests: (json['tests'] as List? ?? const [])
        .map(
          (t) => TestReceiptEntry.fromJson(Map<String, dynamic>.from(t as Map)),
        )
        .toList(growable: false),
  );

  /// SHA-256 (hex) of [content] — shared by the writer and the checker.
  static String digestOf(String content) =>
      crypto.sha256.convert(utf8.encode(content)).toString();
}

/// Reads and writes per-entity test receipts under
/// `<project>/.zfa/receipts/test-<entitySnake>.json`.
class TestReceiptStore {
  final String projectRoot;

  const TestReceiptStore({required this.projectRoot});

  Directory get directory => Directory(p.join(projectRoot, '.zfa', 'receipts'));

  /// Basename of the receipt document for [entity] (CamelCase -> snake).
  static String fileNameFor(String entity) => 'test-${_snake(entity)}.json';

  /// Persists [receipt] as `test-<entity>.json`, replacing any previous
  /// receipt for the same entity (regeneration supersedes the old proof).
  Future<File> write(TestReceipt receipt) async {
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, fileNameFor(receipt.entity)));
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(receipt.toJson()));
    return file;
  }

  /// Loads every parseable test receipt (files named `test-*.json`).
  /// Corrupted documents are skipped, not fatal.
  Future<List<TestReceipt>> loadAll() async {
    if (!directory.existsSync()) return const [];
    final files =
        directory
            .listSync()
            .whereType<File>()
            .where((f) => p.basename(f.path).startsWith('test-'))
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    final receipts = <TestReceipt>[];
    for (final file in files) {
      try {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        receipts.add(TestReceipt.fromJson(json));
      } catch (_) {
        // Skip corrupted test receipts — one broken document must not
        // erase the proof for every healthy entity.
      }
    }
    return receipts;
  }

  /// Minimal CamelCase -> snake_case for receipt file names. Entity names
  /// are simple identifiers; kept local so the receipt model stays free of
  /// util-layer imports.
  static String _snake(String name) {
    final buffer = StringBuffer();
    for (var i = 0; i < name.length; i++) {
      final ch = name[i];
      if (ch.toUpperCase() == ch && ch.toLowerCase() != ch && i > 0) {
        buffer.write('_');
      }
      buffer.write(ch.toLowerCase());
    }
    return buffer.toString();
  }
}
