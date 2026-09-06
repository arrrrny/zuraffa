/// Datasource receipt persistence (spec #1131, order 2).
///
/// Persists the deterministic datasource receipt at
/// `.zfa/receipts/datasource-<entity>.json` via [ReceiptStore.saveNamed].
/// The document is simultaneously:
///
///   * a `proof.v1` generation receipt — digests of the exact artifact
///     bytes that landed on disk, so `zfa proof check` re-derives every
///     hash and turns red on hand-edits (drift = the artifact no longer
///     proves where it came from),
///   * the interface digest binding — `interface_sha256` is the sha256 of
///     the emitted `<Entity>DataSource` interface file, the contract every
///     implementation is held to, and
///   * the entity source binding — `entity_source` carries the
///     project-relative path and sha256 of the entity source the
///     datasource was generated FROM (spec #1131 order 2), so later entity
///     edits are detectable as drift against the datasource.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../core/project/receipt_store.dart';
import '../../models/generated_file.dart';
import '../../utils/string_utils.dart';
import '../../version.dart';

/// Writes and reads the deterministic datasource receipt for one entity.
class DatasourceReceiptWriter {
  /// The deterministic receipt file name for [entity]. The snake_case
  /// form (`Product` -> `datasource-product.json`) is the name the
  /// standalone datasource path has shipped since spec #977; both the
  /// capability path and that command path converge on it.
  static String receiptFileName(String entity) =>
      'datasource-${StringUtils.camelToSnake(entity)}.json';

  /// The receipt path `zfa datasource verify` reads.
  static String receiptPath(String projectRoot, String entity) =>
      p.join(projectRoot, '.zfa', 'receipts', receiptFileName(entity));

  /// Writes the datasource receipt for a `zfa datasource create` (or
  /// make-path) run.
  ///
  /// [files] are the artifacts the run wrote — only files that exist on
  /// disk with their final bytes are digested (a dry run never calls
  /// this). [outputDir] is the generator output root (`lib/src`), the
  /// anchor for the interface file (data/datasources/<snake>/) and the
  /// entity source (domain/entities/<snake>/). [input] is the resolved
  /// input the generation consumed (#294 audit trail). [methodset] and
  /// [runHash] carry the issue-#996 capability provenance when the caller
  /// resolved them.
  Future<File> write({
    required String projectRoot,
    required String outputDir,
    required String entity,
    required List<GeneratedFile> files,
    required Map<String, dynamic> input,
    String command = 'datasource create',
    String? repro,
    List<String> methodset = const [],
    String? runHash,
  }) async {
    final receiptFiles = <GenerationReceiptFile>[];
    String? interfaceSha256;
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
          '${StringUtils.camelToSnake(entity)}_datasource.dart') {
        interfaceSha256 = digest;
      }
      receiptFiles.add(
        GenerationReceiptFile(
          path: _projectRelativePosix(f.path, projectRoot),
          action: f.action,
          sha256: digest,
          bytes: bytes.length,
          snapshot: keepSnapshot ? file.readAsStringSync() : null,
        ),
      );
    }

    final entityBinding = _entitySourceBinding(
      projectRoot: projectRoot,
      outputDir: outputDir,
      entity: entity,
    );

    final receipt = GenerationReceipt(
      command: command,
      target: entity,
      repro: repro ?? 'zfa datasource create $entity',
      at: DateTime.now().toUtc(),
      generatorVersion: version,
      input: input,
      files: receiptFiles,
      plugin: 'datasource',
      capability: 'create',
      entity: entity,
      methodset: methodset,
      runHash: runHash,
    );

    return ReceiptStore(projectRoot: projectRoot).saveNamed(
      receiptFileName(entity),
      receipt,
      extra: {
        // Spec #1131 order 2: the datasource interface's sha256 — the
        // conformance contract `zfa datasource verify` checks against.
        'interface_sha256': ?interfaceSha256,
        // Spec #1131 order 2: the entity source hash — the spec the
        // datasource was generated FROM.
        'entity_source': ?entityBinding,
      },
    );
  }

  /// Loads the receipt document for [entity], or null when absent or
  /// unparseable. The map carries the proof.v1 fields plus the
  /// datasource-specific bindings (`interface_sha256`, `entity_source`).
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
