/// EngineReceiptWriter (spec 1002, deliverable 3): the auto-receipt.
///
/// Every `zfa make engine <Entity>` run writes `.zfa/engine.receipt.json`
/// recording the entity digest, the methods generated, per-method mock
/// certification, DI wiring, engine check outcome, and the file paths of
/// the generated slice — the machine-checkable summary the exit criteria
/// consume.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../version.dart';
import 'engine_models.dart';
export 'engine_models.dart';

/// Writes and reads `.zfa/engine.receipt.json`.
class EngineReceiptWriter {
  static const String schemaName = 'engine.v1';

  final String projectRoot;

  const EngineReceiptWriter({required this.projectRoot});

  File get receiptFile =>
      File(p.join(projectRoot, '.zfa', 'engine.receipt.json'));

  /// Writes the receipt; returns the file.
  ///
  /// When [featureId] is set (spec 1098): the receipt JSON records
  /// `feature.id`, AND a grouped copy is mirrored under
  /// `.zfa/receipts/<featureId>/engine.receipt.json` so "what did feature
  /// X generate?" is answerable via [loadForFeature]/[groupByFeature].
  Future<File> write({
    required String command,
    required String entityName,
    String? entityPath,
    required List<String> methods,
    required Map<String, bool> mockCertified,
    String? mockDatasourcePath,
    String? mockDataPath,
    required List<String> diFiles,
    required List<String> getItTypes,
    required bool engineCheckPassed,
    required List<EngineCheckFailure> engineCheckFailures,
    required List<String> generatedFiles,
    Map<String, dynamic>? options,
    String? featureId,
  }) async {
    final digest = _entityDigest(entityPath);
    final receipt = <String, dynamic>{
      'schema': schemaName,
      'command': command,
      'target': entityName,
      'at': DateTime.now().toUtc().toIso8601String(),
      'generator_version': version,
      'entity': {'name': entityName, 'path': entityPath, 'digest': digest},
      if (featureId != null) 'feature': {'id': featureId},
      'methods': [
        for (final method in methods)
          {'method': method, 'mock_certified': mockCertified[method] ?? false},
      ],
      'mocks': {
        'datasource': mockDatasourcePath,
        'data': mockDataPath,
        'certified': mockCertified.values.every((certified) => certified),
      },
      'di_wired': {
        'di_files': diFiles,
        'getit_types': getItTypes,
        'getit_types_resolved': getItTypes.length,
      },
      'engine_check': {
        'passed': engineCheckPassed,
        'failures': [
          for (final failure in engineCheckFailures) failure.toJson(),
        ],
      },
      'files': generatedFiles,
      'options': options ?? const <String, dynamic>{},
    };

    await receiptFile.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    final encoded = encoder.convert(receipt);
    await receiptFile.writeAsString(encoded);

    // Spec 1098: mirror the receipt under the feature's receipt group so
    // per-feature attribution accumulates across runs (the top-level
    // engine.receipt.json stays the canonical latest). Each grouped run
    // gets a unique file: engine.receipt.json, engine.receipt-2.json, ...
    if (featureId != null && featureId.isNotEmpty) {
      final groupDir = Directory(
        p.join(projectRoot, '.zfa', 'receipts', featureId),
      );
      await groupDir.create(recursive: true);
      var name = 'engine.receipt.json';
      var counter = 2;
      var groupedFile = File(p.join(groupDir.path, name));
      while (groupedFile.existsSync()) {
        name = 'engine.receipt-$counter.json';
        counter += 1;
        groupedFile = File(p.join(groupDir.path, name));
      }
      await groupedFile.writeAsString(encoded);
    }
    return receiptFile;
  }

  /// Loads the current receipt, or null when none was written yet.
  static Map<String, dynamic>? loadReceipt(String projectRoot) {
    final file = File(p.join(projectRoot, '.zfa', 'engine.receipt.json'));
    if (!file.existsSync()) return null;
    try {
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Every grouped receipt attributed to [featureId] (spec 1098).
  ///
  /// Reads `.zfa/receipts/<featureId>/engine.receipt.json` copies written
  /// by [write]. Empty when the feature has no receipts.
  static List<Map<String, dynamic>> loadForFeature(
    String projectRoot,
    String featureId,
  ) {
    final dir = Directory(p.join(projectRoot, '.zfa', 'receipts', featureId));
    if (!dir.existsSync()) return const [];
    final receipts = <Map<String, dynamic>>[];
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final decoded = jsonDecode(entity.readAsStringSync());
        if (decoded is Map<String, dynamic>) receipts.add(decoded);
      } catch (_) {
        // A corrupt receipt never breaks attribution for the rest.
      }
    }
    return receipts;
  }

  /// Groups every grouped receipt under `<projectRoot>/.zfa/receipts/`
  /// by feature id (spec 1098). Directories that don't parse as receipts
  /// are skipped.
  static Map<String, List<Map<String, dynamic>>> groupByFeature(
    String projectRoot,
  ) {
    final receiptsRoot = Directory(p.join(projectRoot, '.zfa', 'receipts'));
    if (!receiptsRoot.existsSync()) return const {};
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final entity in receiptsRoot.listSync()) {
      if (entity is! Directory) continue;
      final featureId = p.basename(entity.path);
      final receipts = loadForFeature(projectRoot, featureId);
      if (receipts.isNotEmpty) grouped[featureId] = receipts;
    }
    return grouped;
  }

  String? _entityDigest(String? entityPath) {
    if (entityPath == null) return null;
    final file = File(p.join(projectRoot, entityPath));
    if (!file.existsSync()) return null;
    return crypto.sha256.convert(file.readAsBytesSync()).toString();
  }
}
