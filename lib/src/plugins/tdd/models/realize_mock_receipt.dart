/// The `realize.<Entity>.firestore.receipt.json` differential receipt
/// (spec 1009, issue #1009): the per-method Tier-1 vs Tier-2 comparison
/// the differential gate records.
///
/// Written by `zfa tdd realize-mock <Entity> --against=firestore` next to
/// the committed Tier-1 contract artifacts (`test/mock/<snake>/`), with
/// one entry per pinned interface method:
/// `{method, tier1_result, tier2_result, diff: none|mismatch}`.
///
/// Gate semantics (per-entity, attribution-honest):
/// - `mismatch`   — at least one method diverges (tier1 != tier2) → the
///   gate exits 1 and names the divergent methods;
/// - `tier1-red`  — no divergence, but the Tier-1 contract itself is red
///   → the gate exits 2 and refuses (fix the mock first; blaming the
///   Tier-2 adapter for a broken baseline would be attribution-dishonest);
/// - `certified`  — every method passes on BOTH sides and agrees → exit 0.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../utils/string_utils.dart';

/// One per-method differential row.
class RealizeMockMethodResult {
  const RealizeMockMethodResult({
    required this.method,
    required this.tier1Passed,
    required this.tier2Passed,
  });

  final String method;
  final bool tier1Passed;
  final bool tier2Passed;

  String get tier1Result => tier1Passed ? 'pass' : 'fail';
  String get tier2Result => tier2Passed ? 'pass' : 'fail';

  /// `mismatch` iff the two tiers disagree on this method.
  String get diff => tier1Passed == tier2Passed ? 'none' : 'mismatch';

  Map<String, dynamic> toJson() => {
    'method': method,
    'tier1_result': tier1Result,
    'tier2_result': tier2Result,
    'diff': diff,
  };
}

/// The overall gate verdict for one realize-mock run.
enum RealizeMockGate {
  certified('certified'),
  mismatch('mismatch'),
  tier1Red('tier1-red');

  const RealizeMockGate(this.label);
  final String label;
}

/// The differential receipt document.
class RealizeMockReceipt {
  RealizeMockReceipt({
    required this.entity,
    required this.interfaceName,
    required this.against,
    required this.contractTestPath,
    required this.contractDigest,
    required this.tier2Subject,
    required this.tier2TestDigest,
    required this.methods,
    required this.sandbox,
    DateTime? runAt,
  }) : runAt = runAt ?? DateTime.now().toUtc();

  static const int schema = 1;
  static const int spec = 1009;

  final String entity;
  final String interfaceName;

  /// The adapter backend the Tier-2 side simulates (`firestore`).
  final String against;

  /// Project-relative path of the committed Tier-1 contract test.
  final String contractTestPath;

  /// SHA-256 (lowercase hex) of the committed Tier-1 contract test bytes.
  final String contractDigest;

  /// The Tier-2 subject class name (e.g. `LoginTier2MockProvider`).
  final String tier2Subject;

  /// SHA-256 of the subject-swapped contract test the Tier-2 side ran.
  final String tier2TestDigest;

  final List<RealizeMockMethodResult> methods;

  /// Sandbox evidence per tier: runner, analyze counts, test counts.
  final Map<String, dynamic> sandbox;

  final DateTime runAt;

  /// Methods whose results diverge between the tiers.
  List<String> get divergences => [
    for (final m in methods)
      if (m.diff == 'mismatch') m.method,
  ];

  /// Tier-1 methods that failed (the baseline contract is red).
  List<String> get tier1Failures => [
    for (final m in methods)
      if (!m.tier1Passed) m.method,
  ];

  RealizeMockGate get gate {
    if (divergences.isNotEmpty) return RealizeMockGate.mismatch;
    if (tier1Failures.isNotEmpty) return RealizeMockGate.tier1Red;
    return RealizeMockGate.certified;
  }

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'spec': spec,
    'entity': entity,
    'interface': interfaceName,
    'against': against,
    'contract_test': contractTestPath,
    'contract_digest': contractDigest,
    'tier2_subject': tier2Subject,
    'tier2_test_digest': tier2TestDigest,
    'methods': [for (final m in methods) m.toJson()],
    'divergence': divergences,
    'result': gate.label,
    'sandbox': sandbox,
    'run_at': runAt.toUtc().toIso8601String(),
  };

  static RealizeMockReceipt? fromJson(Map<String, dynamic> json) {
    final entity = json['entity'] as String?;
    final interfaceName = json['interface'] as String?;
    final against = json['against'] as String?;
    if (entity == null || interfaceName == null || against == null) return null;
    final methods = <RealizeMockMethodResult>[];
    for (final m in (json['methods'] as List<dynamic>? ?? const [])) {
      if (m is Map<String, dynamic> &&
          m['method'] is String &&
          m['tier1_result'] is String &&
          m['tier2_result'] is String) {
        methods.add(
          RealizeMockMethodResult(
            method: m['method'] as String,
            tier1Passed: m['tier1_result'] == 'pass',
            tier2Passed: m['tier2_result'] == 'pass',
          ),
        );
      }
    }
    return RealizeMockReceipt(
      entity: entity,
      interfaceName: interfaceName,
      against: against,
      contractTestPath: json['contract_test'] as String? ?? '',
      contractDigest: json['contract_digest'] as String? ?? '',
      tier2Subject: json['tier2_subject'] as String? ?? '',
      tier2TestDigest: json['tier2_test_digest'] as String? ?? '',
      methods: methods,
      sandbox: (json['sandbox'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
      runAt: DateTime.tryParse(json['run_at'] as String? ?? ''),
    );
  }

  /// SHA-256 of a source document's bytes.
  static String digestOf(String source) =>
      sha256.convert(utf8.encode(source)).toString();
}

/// Canonical receipt path inside a project:
/// `test/mock/<snake>/realize.<Entity>.firestore.receipt.json`.
String realizeMockReceiptPath(String entityName, String against) => p.join(
  'test',
  'mock',
  StringUtils.camelToSnake(entityName),
  'realize.$entityName.$against.receipt.json',
);

/// Read a realize-mock receipt from disk; null when absent or unparseable.
RealizeMockReceipt? loadRealizeMockReceipt(
  String projectRoot,
  String entityName,
  String against,
) {
  final file = File(
    p.join(projectRoot, realizeMockReceiptPath(entityName, against)),
  );
  if (!file.existsSync()) return null;
  try {
    final doc = jsonDecode(file.readAsStringSync());
    if (doc is Map<String, dynamic>) return RealizeMockReceipt.fromJson(doc);
  } catch (_) {
    // A corrupt receipt is not a result — treat as absent.
  }
  return null;
}

extension RealizeMockReceiptIo on RealizeMockReceipt {
  /// Write as pretty JSON to [file] (parent dirs created).
  Future<File> writeTo(File file) async {
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    return file.writeAsString('${encoder.convert(toJson())}\n');
  }
}
