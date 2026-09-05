/// The `mock-cert.<Entity>.json` receipt (spec 1001, issue #1001): the
/// per-method proof that a Tier-1 mock satisfies its interface, plus the
/// SHA-256 digest of the contract test that proved it.
///
/// Written by `zfa mock create <Entity> --certify` next to the committed
/// contract test (`test/mock/<snake>/mock-cert.<Entity>.json`) and — via
/// `zfa mock certify <Entity>` — committed into the feature's
/// `tdd/fixtures/` directory as a #832 registry entry (hashed into the
/// fixture manifest's world digest).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'mock_certification_sandbox.dart';

/// The receipt document for one certified mock.
class MockCertReceipt {
  MockCertReceipt({
    required this.entity,
    required this.interfaceName,
    required this.subjectPath,
    required this.contractTestPath,
    required this.contractDigest,
    required this.methods,
    required this.sandbox,
    required this.seed,
    DateTime? certifiedAt,
  }) : certifiedAt = certifiedAt ?? DateTime.now().toUtc();

  static const int schema = 1;
  static const int spec = 1001;

  final String entity;
  final String interfaceName;
  final String subjectPath;
  final String contractTestPath;

  /// SHA-256 (lowercase hex) of the contract test file bytes.
  final String contractDigest;

  /// Ordered per-method satisfaction: name -> satisfied.
  final List<MapEntry<String, bool>> methods;

  /// Sandbox evidence: runner, analyze issue/error counts, test counts.
  final Map<String, dynamic> sandbox;

  /// The deterministic generation seed recorded when present.
  final int? seed;

  final DateTime certifiedAt;

  bool get allSatisfied => methods.isNotEmpty && methods.every((m) => m.value);

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'spec': spec,
    'entity': entity,
    'interface': interfaceName,
    'subject': subjectPath,
    'contract_test': contractTestPath,
    'contract_digest': contractDigest,
    'methods': [
      for (final m in methods) {'name': m.key, 'satisfied': m.value},
    ],
    'sandbox': sandbox,
    if (seed != null) 'seed': seed,
    'certified_at': certifiedAt.toUtc().toIso8601String(),
  };

  static MockCertReceipt? fromJson(Map<String, dynamic> json) {
    final entity = json['entity'] as String?;
    final interfaceName = json['interface'] as String?;
    if (entity == null || interfaceName == null) return null;
    final methods = <MapEntry<String, bool>>[];
    for (final m in (json['methods'] as List<dynamic>? ?? const [])) {
      if (m is Map<String, dynamic> &&
          m['name'] is String &&
          m['satisfied'] is bool) {
        methods.add(MapEntry(m['name'] as String, m['satisfied'] as bool));
      }
    }
    return MockCertReceipt(
      entity: entity,
      interfaceName: interfaceName,
      subjectPath: json['subject'] as String? ?? '',
      contractTestPath: json['contract_test'] as String? ?? '',
      contractDigest: json['contract_digest'] as String? ?? '',
      methods: methods,
      sandbox: (json['sandbox'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
      seed: json['seed'] is int ? json['seed'] as int : null,
      certifiedAt: DateTime.tryParse(json['certified_at'] as String? ?? ''),
    );
  }

  /// SHA-256 of the contract test source bytes.
  static String digestOf(String contractTestSource) =>
      sha256.convert(utf8.encode(contractTestSource)).toString();

  /// Build the receipt from a sandbox run.
  static MockCertReceipt fromRun({
    required String entity,
    required String interfaceName,
    required String subjectPath,
    required String contractTestPath,
    required String contractTestSource,
    required MockCertificationRun run,
    required List<String> methodNames,
    int? seed,
  }) {
    return MockCertReceipt(
      entity: entity,
      interfaceName: interfaceName,
      subjectPath: subjectPath,
      contractTestPath: contractTestPath,
      contractDigest: digestOf(contractTestSource),
      methods: [
        for (final name in methodNames)
          MapEntry(name, run.methodOutcomes[name] ?? false),
      ],
      sandbox: {
        'runner': run.runner,
        'analyze_issues': run.analyzeIssues,
        'analyze_errors': run.analyzeErrors,
        'tests_passed': run.passedTests.length,
        'tests_failed': run.failedTests.length,
      },
      seed: seed,
    );
  }
}

/// Read/write helpers for the receipt file locations.
extension MockCertReceiptIo on MockCertReceipt {
  /// Write as pretty JSON to [file] (parent dirs created).
  Future<File> writeTo(File file) async {
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    return file.writeAsString('${encoder.convert(toJson())}\n');
  }
}

/// Read a receipt from `test/mock/<snake>/mock-cert.<Entity>.json` under
/// [projectRoot]; null when absent or unparseable.
MockCertReceipt? loadMockCertReceipt(String projectRoot, String entityName) {
  final file = File(p.join(projectRoot, _receiptRel(entityName)));
  if (!file.existsSync()) return null;
  try {
    final doc = jsonDecode(file.readAsStringSync());
    if (doc is Map<String, dynamic>) return MockCertReceipt.fromJson(doc);
  } catch (_) {
    // A corrupt receipt is not a certification — treat as absent.
  }
  return null;
}

String _receiptRel(String entityName) =>
    p.join('test', 'mock', _snake(entityName), 'mock-cert.$entityName.json');

String _snake(String s) => s
    .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}')
    .replaceFirst(RegExp('^_'), '');
