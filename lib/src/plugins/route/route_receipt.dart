// Route table receipt persistence (issue #971 order 3, spec 0971 T003).
//
// Persists the route table as a proof artifact at the deterministic path
// `.zfa/receipts/routes-<Entity>.json` via ReceiptStore. The document is
// simultaneously:
//
//   * a proof.v1 generation receipt — digests of the exact artifact bytes
//     that landed on disk, so `zfa proof check` re-derives every hash and
//     turns red on hand-edits (drift = the artifact no longer proves where
//     it came from), and
//   * the route table AS DATA — routes, deepLinks, schemeRegistrations,
//     plus the route-table test path AND its hash — so the #963
//     route-coverage ledger consumes this file instead of re-parsing Dart.

import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../core/project/receipt_store.dart';
import '../../models/generated_file.dart';
import '../../version.dart';

/// Writes the deterministic routes receipt for one entity.
class RouteReceiptWriter {
  /// The deterministic receipt file name for [entity] (PascalCase
  /// entity identity, e.g. `Product` -> `routes-Product.json`).
  static String receiptFileName(String entity) => 'routes-$entity.json';

  /// The receipt path the #963 ledger (and `zfa route verify`) reads.
  static String receiptPath(String projectRoot, String entity) =>
      p.join(projectRoot, '.zfa', 'receipts', receiptFileName(entity));

  /// Writes the routes receipt for a `route create` run.
  ///
  /// [files] are the artifacts the run wrote; [envelope] is the verdict
  /// envelope (schema:1) built from the same run — its route-table
  /// fields ride along in the document for the ledger. Receipt files are
  /// only digested when they exist on disk with final bytes (a dry run
  /// never calls this).
  Future<File> writeForCreate({
    required String projectRoot,
    required String entity,
    required List<GeneratedFile> files,
    required Map<String, dynamic> envelope,
    required Map<String, dynamic> input,
  }) async {
    final receiptFiles = <GenerationReceiptFile>[];
    for (final f in files) {
      if (f.action != 'created' && f.action != 'overwritten') continue;
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

    // The route-table test digest binds the PROOF ARTIFACT this run
    // leaves behind (issue #842) into the ledger row.
    final testPath = envelope['routeTableTestPath'] as String?;
    final testHash = testPath == null
        ? null
        : await _sha256Of(p.join(projectRoot, testPath));

    final receipt = GenerationReceipt(
      command: 'zfa route create',
      target: entity,
      repro: 'zfa route create $entity',
      at: DateTime.now().toUtc(),
      generatorVersion: version,
      input: input,
      files: receiptFiles,
    );

    return ReceiptStore(projectRoot: projectRoot).saveNamed(
      receiptFileName(entity),
      receipt,
      extra: {
        'routes': envelope['routes'],
        'deepLinks': envelope['deepLinks'],
        'schemeRegistrations': envelope['schemeRegistrations'],
        'routeTableTestPath': testPath,
        'routeTableTestSha256': testHash,
      },
    );
  }

  Future<String?> _sha256Of(String absolutePath) async {
    final file = File(absolutePath);
    if (!file.existsSync()) return null;
    return crypto.sha256.convert(file.readAsBytesSync()).toString();
  }

  static String _projectRelativePosix(String filePath, String projectRoot) {
    final rel = p.isAbsolute(filePath)
        ? p.relative(filePath, from: projectRoot)
        : filePath;
    return p.posix.normalize(p.posix.joinAll(p.split(rel)));
  }
}
