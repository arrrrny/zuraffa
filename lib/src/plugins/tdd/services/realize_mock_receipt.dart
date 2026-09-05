/// The realize-mock differential receipt (issue #1009): the
/// machine-readable record `zfa tdd realize-mock <Entity>
/// --against=firestore` writes after running the same contract cases
/// through the Tier-1 mock and the Firestore-shaped Tier-2 adapter.
///
/// The document is deliberately double-shaped:
///
/// 1. **The differential payload** — top-level `methods`, one record per
///    contract case: `{method, tier1_result, tier2_result, diff:
///    none|mismatch}`, plus the per-entity `verdict` the gate enforces.
/// 2. **The `proof.v1` envelope** — the `schema`/`command`/`target`/
///    `repro`/`at`/`generator_version`/`input`/`files` keys
///    [GenerationReceipt] parses, so `zfa proof check` loads the receipt
///    (it counts it, and its empty `files` list makes it produce no
///    findings — the receipt proves the differential run itself, not a
///    tree artifact).
///
/// The file lives at `.zfa/receipts/realize.<Entity>.<against>.receipt.json`
/// — a stable name, so one file per (entity, against) pair carries the
/// latest differential state (re-running the gate replaces it).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// One per-method comparison row: the method, both tiers' results, and
/// the verdict on their equality.
class RealizeMockMethodRecord {
  const RealizeMockMethodRecord({
    required this.method,
    required this.tier1Result,
    required this.tier2Result,
    required this.diff,
  });

  /// The contract method this row compared (the fixture case's `op`).
  final String method;

  /// The Tier-1 mock's result (recorded oracle or driver output).
  final Object? tier1Result;

  /// The Tier-2 (Firestore-shaped) adapter's result.
  final Object? tier2Result;

  /// `none` when both tiers produced the same JSON, `mismatch` when they
  /// diverged (value OR type — the comparison is on the JSON encoding,
  /// so `42` vs `'42'` is a mismatch).
  final String diff;

  bool get isMismatch => diff == 'mismatch';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'method': method,
    'tier1_result': tier1Result,
    'tier2_result': tier2Result,
    'diff': diff,
  };
}

/// Writes the differential receipt under `.zfa/receipts/`.
class RealizeMockReceiptWriter {
  const RealizeMockReceiptWriter({required this.projectRoot});

  /// The target project root (`.zfa/receipts/` lives under it).
  final String projectRoot;

  /// The receipt schema stamp for the differential payload (the envelope
  /// stays `proof.v1` — the schema `GenerationReceipt` parses).
  static const differentialSchema = 'realize-mock-diff.v1';

  /// The receipt file for one (entity, against) pair:
  /// `realize.<Entity>.<against>.receipt.json`.
  File fileFor(String entity, String against) => File(
    p.join(
      projectRoot,
      '.zfa',
      'receipts',
      'realize.$entity.$against.receipt.json',
    ),
  );

  /// Builds the receipt document (the double-shaped JSON described on
  /// the library).
  static Map<String, dynamic> documentFor({
    required String entity,
    required String against,
    required String feature,
    required List<String> contractTests,
    required List<RealizeMockMethodRecord> methods,
    required String verdict,
    String generatorVersion = '6.1.0',
  }) {
    return <String, dynamic>{
      'schema': 'proof.v1',
      'command': 'zfa tdd realize-mock',
      'target': entity,
      'repro': 'zfa tdd realize-mock $entity --against=$against',
      'at': DateTime.now().toUtc().toIso8601String(),
      'generator_version': generatorVersion,
      'input': <String, dynamic>{
        'entity': entity,
        'against': against,
        'feature': feature,
        'contract_tests': contractTests,
      },
      'differential_schema': differentialSchema,
      'verdict': verdict,
      'methods': [for (final record in methods) record.toJson()],
      'files': const <dynamic>[],
    };
  }

  /// Writes the receipt (indented JSON + trailing newline) and returns
  /// the file.
  Future<File> write({
    required String entity,
    required String against,
    required String feature,
    required List<String> contractTests,
    required List<RealizeMockMethodRecord> methods,
    required String verdict,
  }) async {
    final file = fileFor(entity, against);
    await file.parent.create(recursive: true);
    final document = documentFor(
      entity: entity,
      against: against,
      feature: feature,
      contractTests: contractTests,
      methods: methods,
      verdict: verdict,
    );
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(document)}\n',
    );
    return file;
  }
}
