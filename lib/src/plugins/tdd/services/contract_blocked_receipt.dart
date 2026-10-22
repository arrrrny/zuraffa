/// `ContractBlockedReceipt` — the BLOCKED verdict's receipt for a failed
/// contract test (issue #1007): `contract-blocked.<feature>.<id>.json`
/// under the project's `.zfa/receipts/` directory, schema
/// `contract-blocked.v1`.
///
/// Distinct from the RED path on purpose: a unit behavior's honest red
/// is certified evidence in `tdd/cycle-log.md`; a contract behavior's
/// failure is a BLOCKED verdict — the declared contract is NOT satisfied
/// — and its durable record is THIS receipt (no red evidence is ever
/// appended for a contract lane, so the cycle cannot ride a contract
/// failure into the green phase). The corpus-economics gap ledger picks
/// the stop up at the highest severity.
///
/// File naming (issue #1997): the behavior id minus the `contract:` row
/// prefix (`contract:A1` -> `A1`), with any remaining non-portable
/// character folded to `-` (colons are illegal in Windows file names —
/// the same portability rule `ReceiptStore` applies) — AND the FEATURE
/// the behavior belongs to: `contract-blocked.<feature>.<id>.json`.
/// The feature is part of the name because the behavior id alone is NOT
/// unique across features: two features that both declare `contract:A1`
/// wrote the SAME path, so one feature's receipt overwrote the other's
/// and the second feature's blocked contract had no receipt at all.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The receipt payload (schema `contract-blocked.v1`).
class ContractBlockedReceipt {
  const ContractBlockedReceipt({
    required this.behavior,
    required this.feature,
    required this.contract,
    required this.command,
    required this.exitCode,
    required this.outputExcerpt,
    required this.blockedAt,
  });

  /// The behavior id (`contract:A1`).
  final String behavior;

  /// The feature the contract behavior belongs to.
  final String feature;

  /// The declared contract (`User.validateEmail`).
  final String contract;

  /// The runner command that executed the contract test.
  final String command;

  /// The runner's exit code.
  final int exitCode;

  /// The first lines of the runner transcript (the failing assertion).
  final String outputExcerpt;

  /// ISO-8601 UTC timestamp of the blocked verdict.
  final String blockedAt;

  static const String schema = 'contract-blocked.v1';

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'behavior': behavior,
    'feature': feature,
    'kind': 'contract',
    'contract': contract,
    'classification': 'blocked',
    'command': command,
    'exit_code': exitCode,
    'output_excerpt': outputExcerpt,
    'blocked_at': blockedAt,
    'reason':
        'the declared contract is not satisfied by the implementation — '
        'the cycle is BLOCKED and cannot proceed to GREEN (issue #1007)',
  };

  static ContractBlockedReceipt? fromFile(String path) {
    try {
      final json = jsonDecode(File(path).readAsStringSync());
      if (json is! Map) return null;
      return ContractBlockedReceipt(
        behavior: json['behavior'] as String,
        feature: json['feature'] as String,
        contract: json['contract'] as String? ?? '',
        command: json['command'] as String? ?? '',
        exitCode: json['exit_code'] as int? ?? 1,
        outputExcerpt: json['output_excerpt'] as String? ?? '',
        blockedAt: json['blocked_at'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

/// Writes (and names) contract-blocked receipts under
/// `<project>/.zfa/receipts/`.
class ContractBlockedReceiptStore {
  const ContractBlockedReceiptStore({required this.projectRoot});

  final String projectRoot;

  Directory get directory => Directory(p.join(projectRoot, '.zfa', 'receipts'));

  /// The receipt file name for [behaviorId] in [feature]: the
  /// `contract:` row prefix is stripped (`contract:A1` -> `A1`), every
  /// remaining non-portable character folds to `-`, and the feature is
  /// part of the name (`contract-blocked.<feature>.<id>.json`, issue
  /// #1997) — two features declaring the same behavior id must never
  /// write the same file.
  ///
  /// Without a feature the LEGACY name (`contract-blocked.<id>.json`) is
  /// produced: that is the name a pre-#1997 run left behind, and [read]
  /// still adopts it — for its OWN feature only.
  static String fileNameFor(String behaviorId, {String? feature}) {
    final id = _sanitize(_stripContractPrefix(behaviorId));
    if (feature == null || feature.isEmpty) {
      return 'contract-blocked.$id.json';
    }
    return 'contract-blocked.${_sanitize(feature)}.$id.json';
  }

  /// The receipt's path for [behaviorId] in [feature].
  String pathFor(String behaviorId, {String? feature}) =>
      p.join(directory.path, fileNameFor(behaviorId, feature: feature));

  /// The LEGACY (pre-#1997) receipt path for [behaviorId] — the
  /// feature-less name a pre-fix run left behind.
  String legacyPathFor(String behaviorId) => pathFor(behaviorId);

  /// Reads the receipt of [behaviorId] for [feature]: the namespaced
  /// path first, then the LEGACY feature-less path — but only when the
  /// legacy receipt's own `feature` field names [feature]. A legacy
  /// receipt another feature wrote is NEVER adopted: that shared path is
  /// exactly the collision issue #1997 reports.
  ContractBlockedReceipt? read({
    required String behaviorId,
    required String feature,
  }) {
    final namespaced = ContractBlockedReceipt.fromFile(
      pathFor(behaviorId, feature: feature),
    );
    if (namespaced != null) return namespaced;
    final legacy = ContractBlockedReceipt.fromFile(legacyPathFor(behaviorId));
    if (legacy == null || legacy.feature != feature) return null;
    return legacy;
  }

  /// Persist [receipt] for its behavior id; returns the file path. The
  /// receipt's OWN feature names the file (issue #1997).
  Future<String> write(ContractBlockedReceipt receipt) async {
    await directory.create(recursive: true);
    final path = pathFor(receipt.behavior, feature: receipt.feature);
    await File(path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(receipt.toJson()),
    );
    return path;
  }

  /// The behavior id without its `contract:` row prefix.
  static String _stripContractPrefix(String behaviorId) {
    const prefix = 'contract:';
    return behaviorId.startsWith(prefix)
        ? behaviorId.substring(prefix.length)
        : behaviorId;
  }

  /// Folds every non-portable character to `-` (the same portability
  /// rule `ReceiptStore` applies to its own file names).
  static String _sanitize(String segment) =>
      segment.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '-');
}
