/// The cert-gate refusal receipt (spec 1110, issue #1110):
/// `engine.gate.<Entity>.refused.json`.
///
/// "Cert refusal reason is a receipt, not an exception." When the gate
/// blocks — a CORE entity referenced by the engine tree is uncertified,
/// unsatisfied, corrupt, or stale — the block writes a machine-readable
/// receipt carrying the entity, the reason, and the EXACT fix command
/// (`zfa mock create <Entity> --certify`), so `zfa tdd status` and the
/// fix tooling can render the recovery path without parsing stdout.
///
/// Two homes, one schema (`engine.gate.v1`):
///
/// - `zfa engine check <Entity>` (and the `zfa make engine` tail check)
///   write the receipt next to the engine receipt, under `.zfa/`;
/// - `zfa tdd run-engine <feature>` (the pre-flight gate) writes it into
///   the feature's receipt home, `specs/<feature>/tdd/`, where the lane
///   receipts live and `zfa tdd status` reads.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Writes and reads `engine.gate.<Entity>.refused.json`.
class EngineGateReceipt {
  static const String schemaName = 'engine.gate.v1';

  /// The doc reference carried in `refs` — the certification command's
  /// specification (the spec that introduced the receipts and the gate).
  static const List<String> defaultRefs = [
    'specs/1001-certified-mocks-contract-tests/spec.md',
    'https://github.com/arrrrny/zuraffa/issues/1110',
  ];

  const EngineGateReceipt();

  /// The refusal receipt path (project-root relative) for [entity] under
  /// `.zfa/` — the engine-check home.
  static String refusedPath(String entity) =>
      p.join('.zfa', 'engine.gate.$entity.refused.json');

  /// The refusal receipt path for [entity] scoped to a feature's tdd
  /// directory (`<featureDir>/tdd/`) — the run-engine home.
  static String refusedPathInFeature(String featureDir, String entity) =>
      p.join(featureDir, 'tdd', 'engine.gate.$entity.refused.json');

  /// Writes the refusal receipt. [featureDir] redirects the receipt to
  /// the feature's tdd directory (the run-engine preflight); without it
  /// the receipt lands under `.zfa/` (the engine-check path). Returns
  /// the project-root-relative path of the written receipt.
  static Future<String> write({
    required String projectRoot,
    required String entity,
    required String reason,
    String? fix,
    List<String> refs = defaultRefs,
    String? command,
    String? featureDir,
  }) async {
    final absPath = featureDir != null && featureDir.isNotEmpty
        ? (p.isAbsolute(featureDir)
            ? refusedPathInFeature(featureDir, entity)
            : p.join(projectRoot, refusedPathInFeature(featureDir, entity)))
        : p.join(projectRoot, refusedPath(entity));
    final file = File(absPath);
    await file.parent.create(recursive: true);
    final doc = <String, dynamic>{
      'schema': schemaName,
      'entity': entity,
      'reason': reason,
      'fix': fix ?? _fixFor(entity),
      'refs': refs,
      if (command != null && command.isNotEmpty) 'command': command,
      'at': DateTime.now().toUtc().toIso8601String(),
    };
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(doc)}\n');
    return p.relative(file.path, from: projectRoot);
  }

  /// Loads the receipt for [entity] (`.zfa/` home by default; the
  /// feature home when [featureDir] is given). Null when absent or
  /// unparseable — a corrupt refusal is not a block, the gate recomputes
  /// the verdict live.
  static Map<String, dynamic>? load({
    required String projectRoot,
    required String entity,
    String? featureDir,
  }) {
    final rel = featureDir != null && featureDir.isNotEmpty
        ? refusedPathInFeature(featureDir, entity)
        : refusedPath(entity);
    final file = File(p.join(projectRoot, rel));
    if (!file.existsSync()) return null;
    try {
      final doc = jsonDecode(file.readAsStringSync());
      if (doc is Map<String, dynamic>) return doc;
    } catch (_) {
      // Corrupt refusal receipt — the gate's verdict is recomputed live
      // on every check, so this is informational only.
    }
    return null;
  }

  /// Deletes a stale refusal receipt — the gate healed (the entity got
  /// certified), so the refusal must not outlive its block.
  static void clear({
    required String projectRoot,
    required String entity,
    String? featureDir,
  }) {
    final rel = featureDir != null && featureDir.isNotEmpty
        ? refusedPathInFeature(featureDir, entity)
        : refusedPath(entity);
    final file = File(p.join(projectRoot, rel));
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {
        // Best-effort heal; the next check rewrites the verdict anyway.
      }
    }
  }

  /// Every refusal receipt in a feature's tdd directory (for `zfa tdd
  /// status` rendering), entity name → document.
  static Map<String, Map<String, dynamic>> loadAllInFeature(String featureDir) {
    final dir = Directory(p.join(featureDir, 'tdd'));
    if (!dir.existsSync()) return const {};
    final found = <String, Map<String, dynamic>>{};
    for (final entry in dir.listSync()) {
      final name = p.basename(entry.path);
      if (entry is! File ||
          !name.startsWith('engine.gate.') ||
          !name.endsWith('.refused.json')) {
        continue;
      }
      try {
        final doc = jsonDecode(entry.readAsStringSync());
        if (doc is Map<String, dynamic> && doc['entity'] is String) {
          found[doc['entity'] as String] = doc;
        }
      } catch (_) {
        // A corrupt refusal receipt never breaks status rendering.
      }
    }
    return found;
  }

  static String _fixFor(String entity) => 'zfa mock create $entity --certify';
}
