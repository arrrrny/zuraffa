/// `ContractBlockedReceipt` — the BLOCKED verdict's receipt for a failed
/// contract test (issue #1007): `contract-blocked.<id>.json` under the
/// project's `.zfa/receipts/` directory, schema `contract-blocked.v1`.
///
/// Distinct from the RED path on purpose: a unit behavior's honest red
/// is certified evidence in `tdd/cycle-log.md`; a contract behavior's
/// failure is a BLOCKED verdict — the declared contract is NOT satisfied
/// — and its durable record is THIS receipt (no red evidence is ever
/// appended for a contract lane, so the cycle cannot ride a contract
/// failure into the green phase). The corpus-economics gap ledger picks
/// the stop up at the highest severity.
///
/// File naming: the behavior id minus the `contract:` row prefix
/// (`contract:A1` -> `contract-blocked.A1.json`), with any remaining
/// non-portable character folded to `-` (colons are illegal in Windows
/// file names — the same portability rule `ReceiptStore` applies).
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

  /// The receipt file name for [behaviorId]: the `contract:` row prefix
  /// is stripped (`contract:A1` -> `A1`) and every remaining
  /// non-portable character folds to `-`.
  static String fileNameFor(String behaviorId) {
    var id = behaviorId;
    const prefix = 'contract:';
    if (id.startsWith(prefix)) id = id.substring(prefix.length);
    final sanitized = id.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '-');
    return 'contract-blocked.$sanitized.json';
  }

  /// The receipt's path for [behaviorId].
  String pathFor(String behaviorId) =>
      p.join(directory.path, fileNameFor(behaviorId));

  /// Persist [receipt] for its behavior id; returns the file path.
  Future<String> write(ContractBlockedReceipt receipt) async {
    await directory.create(recursive: true);
    final path = pathFor(receipt.behavior);
    await File(path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(receipt.toJson()),
    );
    return path;
  }
}
