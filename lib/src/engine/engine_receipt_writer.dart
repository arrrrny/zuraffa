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

import '../utils/string_utils.dart';
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

  // ---------------------------------------------------------------------
  // Issue #1109: the v2 engine receipt (specs/<feature>/tdd/).
  // ---------------------------------------------------------------------

  /// Schema name of the issue-shaped receipt (#1014/CERT-GATE reads it).
  static const String v2SchemaName = 'engine.receipt.v2';

  /// Writes the v2 engine receipt for one entity to
  /// `specs/<feature>/tdd/engine.receipt.json` (issue #1109, contract
  /// `specs/077-make-engine-preset/contracts/engine-receipt-v2.md`).
  ///
  /// Unlike the v1 writer above, this receipt is the cross-pipeline
  /// contract: `{schema, entity, methods:[{name, mock_certified,
  /// mock_class}], source_files}` with `source_files` sorted and the file
  /// overwritten ATOMICALLY (write temp, rename) — re-runs replace, never
  /// append. Written even when some methods are uncertified: the `false`
  /// values are the CERT-GATE signal.
  Future<File> writeV2({
    required String projectRoot,
    required String feature,
    required String entityName,
    required List<EngineReceiptMethod> methods,
    required List<String> sourceFiles,
  }) async {
    final receipt = <String, dynamic>{
      'schema': v2SchemaName,
      'entity': entityName,
      'methods': [for (final method in methods) method.toJson()],
      'source_files': ([...sourceFiles]..sort()),
    };

    final target = receiptV2File(projectRoot, feature);
    await target.parent.create(recursive: true);
    final encoded = const JsonEncoder.withIndent('  ').convert(receipt);
    // Atomic overwrite: write a temp sibling, then rename over the
    // target — a crashed run never leaves a half-written receipt.
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(encoded);
    await temp.rename(target.path);
    return target;
  }

  /// The v2 receipt path for [feature] inside [projectRoot]
  /// (project-root relative).
  static File receiptV2File(String projectRoot, String feature) =>
      File(p.join(projectRoot, 'specs', feature, 'tdd', 'engine.receipt.json'));

  /// Loads the v2 receipt for [entity].
  ///
  /// Resolution order (mirrors the mock-certify #832 convention):
  ///   1. explicit [feature] directory;
  ///   2. entity scan — every `specs/*/tdd/engine.receipt.json` whose
  ///      `entity` matches, newest file first (deterministic: mtime,
  ///      then alphabetical).
  ///
  /// Null when no receipt matches.
  static Map<String, dynamic>? loadV2Receipt(
    String projectRoot, {
    String? feature,
    String? entity,
  }) {
    if (feature != null && feature.isNotEmpty) {
      return _readReceiptJson(receiptV2File(projectRoot, feature));
    }
    if (entity == null) return null;

    final specsDir = Directory(p.join(projectRoot, 'specs'));
    if (!specsDir.existsSync()) return null;
    final candidates = <File>[];
    for (final entry in specsDir.listSync()) {
      if (entry is! Directory) continue;
      final file = receiptV2File(projectRoot, p.basename(entry.path));
      if (!file.existsSync()) continue;
      final receipt = _readReceiptJson(file);
      if (receipt != null && receipt['entity'] == entity) {
        candidates.add(file);
      }
    }
    if (candidates.isEmpty) return null;
    // Newest first; alphabetical as the deterministic tie-breaker.
    candidates.sort((a, b) {
      final byMtime = b.lastModifiedSync().compareTo(a.lastModifiedSync());
      if (byMtime != 0) return byMtime;
      return a.path.compareTo(b.path);
    });
    return _readReceiptJson(candidates.first);
  }

  static Map<String, dynamic>? _readReceiptJson(File file) {
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // A corrupt receipt is reported as absent — the check's
      // missing-receipt failure names the fix.
    }
    return null;
  }

  /// The feature pinned by `.specify/feature.json`, when one exists
  /// (the same convention `zfa mock certify` resolves #832 fixture
  /// directories by).
  static String? pinnedFeature(String projectRoot) {
    final f = File(p.join(projectRoot, '.specify', 'feature.json'));
    if (!f.existsSync()) return null;
    try {
      final json = f.readAsStringSync();
      final m = RegExp(r'"feature_directory"\s*:\s*"([^"]+)"').firstMatch(json);
      return m?.group(1);
    } on FileSystemException {
      return null;
    }
  }

  /// The entity-derived feature directory for fresh projects with no
  /// pinned feature: `User` → `user`. Keeps the receipt (and therefore
  /// `zfa engine check`) working out of the box, per the issue's
  /// fresh-project success criterion.
  static String engineFeatureFallback(String entity) =>
      StringUtils.camelToSnake(entity);
}
