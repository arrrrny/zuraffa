/// Service receipt persistence (SPEC 1127, order 3).
///
/// Persists the deterministic service receipt at
/// `.zfa/receipts/service-<Entity>.json` via [ReceiptStore.saveNamed] —
/// the same stable per-entity contract `provider-<Entity>.json`
/// established (spec 979). The document is simultaneously:
///
///   * a `proof.v1` generation receipt — digests of the exact artifact
///     bytes that landed on disk, so `zfa proof check` re-derives every
///     hash and turns red on hand-edits (drift = the artifact no longer
///     proves where it came from), and
///   * the service ledger AS DATA — the target Service interface, the
///     emitted member names, and the schema knobs (params/returns/type/
///     init) — so `zfa service verify` re-runs the grammar-conformance
///     gate against the exact contract the create run used instead of
///     re-deriving it from flags.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../core/plugin_system/capability_invocation_wrapper.dart';
import '../../core/project/receipt_store.dart';
import '../../models/generated_file.dart';
import '../../version.dart';

/// Writes and reads the deterministic service receipt for one entity.
class ServiceReceiptWriter {
  /// The deterministic receipt file name for [entity] (PascalCase entity
  /// identity, e.g. `SendEmail` -> `service-SendEmail.json`).
  static String receiptFileName(String entity) => 'service-$entity.json';

  /// The receipt path `zfa service verify` and machine readers resolve.
  static String receiptPath(String projectRoot, String entity) =>
      p.join(projectRoot, '.zfa', 'receipts', receiptFileName(entity));

  /// Writes the service receipt for a `zfa service create` run.
  ///
  /// [files] are the artifacts the run wrote — only `created`/
  /// `overwritten`/`updated` entries are digested, and only when they
  /// exist on disk with their final bytes (a dry run never calls this).
  /// [interface] is the generated Service interface class, [methods] the
  /// emitted member names, [input] the schema knobs the run consumed.
  Future<File> write({
    required String projectRoot,
    required String entity,
    required List<GeneratedFile> files,
    required String interface,
    required List<String> methods,
    required Map<String, dynamic> input,
    String? runHash,
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
    if (receiptFiles.isEmpty) {
      throw StateError('no writable service artifacts to prove');
    }

    final receipt = GenerationReceipt(
      command: 'service create',
      target: entity,
      repro: 'zfa service create $entity',
      at: DateTime.now().toUtc(),
      generatorVersion: version,
      input: input,
      files: receiptFiles,
      plugin: 'service',
      capability: 'create',
      entity: entity,
      methodset: methods,
      runHash:
          runHash ??
          CapabilityInvocationWrapper.computeRunHash(
            files: receiptFiles,
            entity: entity,
            methodset: methods,
          ),
      receiptVersion: CapabilityInvocationWrapper.receiptVersion,
    );

    return ReceiptStore(projectRoot: projectRoot).saveNamed(
      receiptFileName(entity),
      receipt,
      extra: {'interface': interface, 'methods': methods, ...input},
    );
  }

  /// Loads the receipt document for [entity], or null when absent or
  /// unparseable. The map carries the proof.v1 fields plus the
  /// service-specific ledger data (`interface`, `methods`, knobs).
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
