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
  }) async {
    final digest = _entityDigest(entityPath);
    final receipt = <String, dynamic>{
      'schema': schemaName,
      'command': command,
      'target': entityName,
      'at': DateTime.now().toUtc().toIso8601String(),
      'generator_version': version,
      'entity': {'name': entityName, 'path': entityPath, 'digest': digest},
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
    await receiptFile.writeAsString(encoder.convert(receipt));
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

  String? _entityDigest(String? entityPath) {
    if (entityPath == null) return null;
    final file = File(p.join(projectRoot, entityPath));
    if (!file.existsSync()) return null;
    return crypto.sha256.convert(file.readAsBytesSync()).toString();
  }
}
