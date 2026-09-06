/// The realization receipt (issue #1193, FR-006): the machine-readable
/// record `zfa tdd realize <feature> --adapter <name>` writes when the
/// MOCKED→REAL swap lands — files, digests, gate outcome, ladder
/// transitions, and the generated/mock/hand provenance ratios.
///
/// The document is deliberately double-shaped (the #1009
/// realize-mock pattern):
///
/// 1. **The realization payload** — top-level `realize_schema`
///    (`realize.v1`), `entities`, `gates`, `ladder`, `ratios`,
///    `simulation_binding`, `hand_deltas`: the swap's own contract.
/// 2. **The `proof.v1` envelope** — the `schema`/`command`/`target`/
///    `repro`/`at`/`generator_version`/`input`/`files` keys
///    [GenerationReceipt] parses, so `zfa proof check` loads the
///    receipt and re-derives every digest. The `files` list carries the
///    rebind-written binding files (`action: update`, final-bytes
///    digest) and the retired simulation manifest (`action: delete`,
///    pre-deletion digest) — the scaffolded adapter file is NEVER
///    listed here (a hand-delta seam is never pretended generated; the
///    nuance ledger is its record).
///
/// The file lives at `.zfa/receipts/realize.<feature>.<adapterName>
/// .receipt.json` — a stable name per (feature, adapter) pair; a
/// re-realization replaces it (the latest swap is the state of record).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/project/receipt_store.dart';

/// One entity's swap record inside the receipt payload.
class EntitySwap {
  const EntitySwap({
    required this.entity,
    required this.mockClass,
    required this.adapterClass,
    required this.adapterFile,
    required this.scaffolded,
    required this.bindingSites,
    required this.interfaceFilesUntouched,
  });

  /// The entity whose mock was realized (e.g. `User`).
  final String entity;

  /// The unbound mock class (e.g. `UserMockDataSource`).
  final String mockClass;

  /// The bound real adapter class (e.g. `UserFirestoreAdapter`).
  final String adapterClass;

  /// Project-relative path of the adapter file.
  final String adapterFile;

  /// Whether the adapter file was scaffolded by this run (a hand-delta
  /// seam) or already existed (hand-written nuance).
  final bool scaffolded;

  /// Binding sites swapped for this entity.
  final int bindingSites;

  /// Domain/interface files proven byte-identical across the swap.
  final int interfaceFilesUntouched;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'entity': entity,
    'mock_class': mockClass,
    'adapter_class': adapterClass,
    'adapter_file': adapterFile,
    'scaffolded': scaffolded,
    'binding_sites': bindingSites,
    'interface_files_untouched': interfaceFilesUntouched,
  };
}

/// Writes the realization receipt under `.zfa/receipts/`.
class RealizeReceiptWriter {
  const RealizeReceiptWriter({required this.projectRoot});

  /// The target project root (`.zfa/receipts/` lives under it).
  final String projectRoot;

  /// The payload schema stamp (the envelope stays `proof.v1` — the
  /// schema [GenerationReceipt] parses).
  static const String payloadSchema = 'realize.v1';

  /// The receipt file for one (feature, adapter) pair:
  /// `realize.<feature>.<adapter>.receipt.json`.
  File fileFor(String feature, String adapterName) => File(
    p.join(
      projectRoot,
      '.zfa',
      'receipts',
      'realize.$feature.$adapterName.receipt.json',
    ),
  );

  /// Builds the receipt document (the double-shaped JSON described on
  /// the library docs).
  static Map<String, dynamic> documentFor({
    required String feature,
    required String adapterName,
    required List<EntitySwap> entities,
    required String contractVerdict,
    required String differentialVerdict,
    required String drift,
    required String threshold,
    required int fixturesRun,
    required Map<String, List<String>> ladder,
    required Map<String, dynamic> ratios,
    required Map<String, dynamic> simulationBinding,
    required List<String> suitePaths,
    required int handDeltas,
    required List<GenerationReceiptFile> files,
    String generatorVersion = '6.1.0',
  }) {
    return <String, dynamic>{
      'schema': 'proof.v1',
      'command': 'zfa tdd realize',
      'target': feature,
      'repro': 'zfa tdd realize $feature --adapter $adapterName',
      'at': DateTime.now().toUtc().toIso8601String(),
      'generator_version': generatorVersion,
      'input': <String, dynamic>{
        'feature': feature,
        'adapter': adapterName,
        'entities': [for (final swap in entities) swap.entity],
        'suite_paths': suitePaths.length,
      },
      // ---- The realization payload ----
      'realize_schema': payloadSchema,
      'entities': [for (final swap in entities) swap.toJson()],
      'gates': <String, dynamic>{
        'contract': contractVerdict,
        'differential': <String, dynamic>{
          'verdict': differentialVerdict,
          'drift': drift,
          'threshold': threshold,
          'fixtures': fixturesRun,
        },
      },
      'ladder': {
        for (final entry in ladder.entries)
          entry.key: List<String>.of(entry.value),
      },
      'ratios': Map<String, dynamic>.of(ratios),
      'simulation_binding': Map<String, dynamic>.of(simulationBinding),
      'hand_deltas': handDeltas,
      'suite_paths': List<String>.of(suitePaths),
      // ---- The proof.v1 envelope's digest bindings ----
      'files': [for (final file in files) file.toJson()],
    };
  }

  /// Writes the receipt (indented JSON + trailing newline) and returns
  /// the file.
  Future<File> write({
    required String feature,
    required String adapterName,
    required List<EntitySwap> entities,
    required String contractVerdict,
    required String differentialVerdict,
    required String drift,
    required String threshold,
    required int fixturesRun,
    required Map<String, List<String>> ladder,
    required Map<String, dynamic> ratios,
    required Map<String, dynamic> simulationBinding,
    required List<String> suitePaths,
    required int handDeltas,
    required List<GenerationReceiptFile> files,
  }) async {
    final file = fileFor(feature, adapterName);
    await file.parent.create(recursive: true);
    final document = documentFor(
      feature: feature,
      adapterName: adapterName,
      entities: entities,
      contractVerdict: contractVerdict,
      differentialVerdict: differentialVerdict,
      drift: drift,
      threshold: threshold,
      fixturesRun: fixturesRun,
      ladder: ladder,
      ratios: ratios,
      simulationBinding: simulationBinding,
      suitePaths: suitePaths,
      handDeltas: handDeltas,
      files: files,
    );
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(document)}\n',
    );
    return file;
  }
}
