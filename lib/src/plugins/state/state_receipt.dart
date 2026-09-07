/// State receipt persistence (spec 1126, order 2).
///
/// Persists the deterministic state receipt at
/// `.zfa/receipts/state-<entity>.json` via [ReceiptStore.saveNamed] —
/// the stable per-entity contract `datasource-<entity>.json`
/// established (spec #977). The document is simultaneously:
///
///   * a `proof.v1` generation receipt — digests of the exact artifact
///     bytes that landed on disk, so `zfa proof check` re-derives every
///     hash and turns red on hand-edits (drift = the artifact no longer
///     proves where it came from),
///   * the artifact digest binding — `state_sha256` is the sha256 of
///     the emitted `<Entity>State` file, the contract
///     `zfa state verify` checks the CURRENT bytes against, and
///   * the entity source binding — `entity_source` carries the
///     project-relative path and sha256 of the entity source the state
///     was generated FROM (spec 1126 order 2), so later entity edits
///     are detectable as "stale: entity changed, state not
///     regenerated".
///
/// The document additionally carries the ledger data the verify gate
/// and the explain surface read: `state_class` (the emitted class) and
/// `methods` (the contract methodset, each method mapping to the
/// `is<Continuous>` member the builder generates).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../core/project/receipt_store.dart';
import '../../models/generated_file.dart';
import '../../utils/string_utils.dart';
import '../../version.dart';

/// Writes and reads the deterministic state receipt for one entity.
class StateReceiptWriter {
  /// The deterministic receipt file name for [entity]. The snake_case
  /// form (`Product` -> `state-product.json`) matches the artifact
  /// naming (`product_state.dart`) and the datasource ledger
  /// convention (spec #977).
  static String receiptFileName(String entity) =>
      'state-${StringUtils.camelToSnake(entity)}.json';

  /// The receipt path `zfa state verify` and machine readers resolve.
  static String receiptPath(String projectRoot, String entity) =>
      p.join(projectRoot, '.zfa', 'receipts', receiptFileName(entity));

  /// Writes the state receipt for a `zfa state create` run.
  ///
  /// [files] are the artifacts the run wrote — only files that exist on
  /// disk with their final bytes are digested (a dry run never calls
  /// this). [stateClass] is the emitted state class name, [methods] the
  /// contract methodset, [input] the resolved input the generation
  /// consumed (audit trail). The entity source hash is bound when the
  /// entity file exists under
  /// `<outputDir>/domain/entities/<snake>/<snake>.dart`; no-entity runs
  /// (and entities that have never been generated) ship no
  /// `entity_source` — the absence is honest, never faked.
  Future<File> write({
    required String projectRoot,
    required String outputDir,
    required String entity,
    required List<GeneratedFile> files,
    required String stateClass,
    required List<String> methods,
    Map<String, dynamic> input = const {},
    String command = 'state create',
    String? repro,
    String? runHash,
  }) async {
    final receiptFiles = <GenerationReceiptFile>[];
    String? stateSha256;
    for (final f in files) {
      final absolute = p.isAbsolute(f.path)
          ? f.path
          : p.join(projectRoot, f.path);
      final file = File(absolute);
      if (!file.existsSync()) continue;
      if (f.action == 'skipped' || f.action == 'deleted') continue;
      final bytes = file.readAsBytesSync();
      final keepSnapshot = bytes.length <= ReceiptStore.maxSnapshotBytes;
      final digest = crypto.sha256.convert(bytes).toString();
      if (p.basename(file.path) ==
          '${StringUtils.camelToSnake(entity)}_state.dart') {
        stateSha256 = digest;
      }
      receiptFiles.add(
        GenerationReceiptFile(
          path: _projectRelativePosix(f.path, projectRoot),
          action: f.action == 'created' ? 'create' : 'update',
          sha256: digest,
          bytes: bytes.length,
          snapshot: keepSnapshot ? file.readAsStringSync() : null,
        ),
      );
    }
    if (receiptFiles.isEmpty) {
      throw StateError('no writable state artifacts to prove');
    }

    final entityBinding = _entitySourceBinding(
      projectRoot: projectRoot,
      outputDir: outputDir,
      entity: entity,
    );

    final receipt = GenerationReceipt(
      command: command,
      target: entity,
      repro: repro ?? 'zfa state create --name $entity',
      at: DateTime.now().toUtc(),
      generatorVersion: version,
      input: input,
      files: receiptFiles,
      plugin: 'state',
      capability: 'create',
      entity: entity,
      methodset: methods,
      runHash: runHash,
    );

    return ReceiptStore(projectRoot: projectRoot).saveNamed(
      receiptFileName(entity),
      receipt,
      extra: {
        // Spec 1126 order 2: the state file's sha256 — the artifact
        // contract `zfa state verify` audits.
        'state_sha256': ?stateSha256,
        // Spec 1126 order 2: the entity source hash — the spec the
        // state was generated FROM.
        'entity_source': ?entityBinding,
        'state_class': stateClass,
        'methods': methods,
      },
    );
  }

  /// Loads the receipt document for [entity], or null when absent or
  /// unparseable. The map carries the proof.v1 fields plus the
  /// state-specific bindings (`state_sha256`, `entity_source`,
  /// `state_class`, `methods`).
  static Map<String, dynamic>? load(String projectRoot, String entity) {
    final file = File(receiptPath(projectRoot, entity));
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// The entity source binding for [entity]: path + sha256 of the entity
  /// file under `<outputDir>/domain/entities/<snake>/<snake>.dart`, or
  /// null when the entity source is absent (no-entity runs).
  static Map<String, dynamic>? _entitySourceBinding({
    required String projectRoot,
    required String outputDir,
    required String entity,
  }) {
    final snake = StringUtils.camelToSnake(entity);
    final entityFile = File(
      p.isAbsolute(outputDir)
          ? p.join(outputDir, 'domain', 'entities', snake, '$snake.dart')
          : p.join(
              projectRoot,
              outputDir,
              'domain',
              'entities',
              snake,
              '$snake.dart',
            ),
    );
    if (!entityFile.existsSync()) return null;
    final bytes = entityFile.readAsBytesSync();
    return {
      'path': _projectRelativePosix(entityFile.path, projectRoot),
      'sha256': crypto.sha256.convert(bytes).toString(),
      'bytes': bytes.length,
    };
  }

  static String _projectRelativePosix(String filePath, String projectRoot) {
    final rel = p.isAbsolute(filePath)
        ? p.relative(filePath, from: projectRoot)
        : filePath;
    return p.normalize(rel).replaceAll('\\', '/');
  }
}
