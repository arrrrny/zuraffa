/// Provider receipt persistence (spec 979, order 1).
///
/// Persists the deterministic provider receipt at
/// `.zfa/receipts/provider-<Entity>.json` via [ReceiptStore.saveNamed].
/// The document is simultaneously:
///
///   * a `proof.v1` generation receipt — digests of the exact artifact
///     bytes that landed on disk, so `zfa proof check` re-derives every
///     hash and turns red on hand-edits (drift = the artifact no longer
///     proves where it came from), and
///   * the provider ledger AS DATA — the target Service interface, the
///     emitted method names, and the stub count — so `zfa provider verify`
///     and the make post-pass consume this file instead of re-deriving
///     the generation contract from flags.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../core/project/receipt_store.dart';
import '../../models/generated_file.dart';
import '../../version.dart';

/// Writes and reads the deterministic provider receipt for one entity.
class ProviderReceiptWriter {
  /// The deterministic receipt file name for [entity] (PascalCase entity
  /// identity, e.g. `Product` -> `provider-Product.json`).
  static String receiptFileName(String entity) => 'provider-$entity.json';

  /// The receipt path `zfa provider verify` and the make post-pass read.
  static String receiptPath(String projectRoot, String entity) =>
      p.join(projectRoot, '.zfa', 'receipts', receiptFileName(entity));

  /// Writes the provider receipt for a `zfa provider create` (or make)
  /// run.
  ///
  /// [files] are the artifacts the run wrote — only `created`/`
  /// `overwritten`/`updated` entries are digested, and only when they
  /// exist on disk with their final bytes (a dry run never calls this).
  /// [interface] is the target Service interface, [methods] the emitted
  /// member names, [stubCount] how many of them still carry the
  /// stub-first body (visibility: stubs are allowed to exist, never to
  /// hide).
  Future<File> write({
    required String projectRoot,
    required String entity,
    required List<GeneratedFile> files,
    required String interface,
    required List<String> methods,
    required int stubCount,
    required Map<String, dynamic> input,
  }) async {
    final receiptFiles = <GenerationReceiptFile>[];
    for (final f in files) {
      if (f.action != 'created' &&
          f.action != 'overwritten' &&
          f.action != 'updated') {
        continue;
      }
      final absolute = p.isAbsolute(f.path)
          ? f.path
          : p.join(projectRoot, f.path);
      final file = File(absolute);
      if (!file.existsSync()) continue;
      final bytes = file.readAsBytesSync();
      final keepSnapshot = bytes.length <= ReceiptStore.maxSnapshotBytes;
      receiptFiles.add(
        GenerationReceiptFile(
          path: _projectRelativePosix(f.path, projectRoot),
          action: f.action == 'created' ? 'create' : 'update',
          sha256: crypto.sha256.convert(bytes).toString(),
          bytes: bytes.length,
          snapshot: keepSnapshot ? file.readAsStringSync() : null,
        ),
      );
    }

    final receipt = GenerationReceipt(
      command: 'zfa provider create',
      target: entity,
      repro: 'zfa provider create --name $entity --force',
      at: DateTime.now().toUtc(),
      generatorVersion: version,
      input: input,
      files: receiptFiles,
    );

    return ReceiptStore(projectRoot: projectRoot).saveNamed(
      receiptFileName(entity),
      receipt,
      extra: {
        'interface': interface,
        'methods': methods,
        'stubCount': stubCount,
      },
    );
  }

  /// Loads the receipt document for [entity], or null when absent or
  /// unparseable. The map carries the proof.v1 fields plus the
  /// provider-specific ledger data (`interface`, `methods`, `stubCount`).
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

  static String _projectRelativePosix(String filePath, String projectRoot) {
    final rel = p.isAbsolute(filePath)
        ? p.relative(filePath, from: projectRoot)
        : filePath;
    return p.normalize(rel).replaceAll('\\', '/');
  }
}
