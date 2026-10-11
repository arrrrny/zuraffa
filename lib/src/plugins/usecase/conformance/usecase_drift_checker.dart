import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../../core/project/receipt_store.dart';
import '../../../utils/string_utils.dart';

/// SPEC 1119 — the entity drift gate (issue #1034 same pattern): the
/// create receipt binds the entity source it consumed
/// (`GenerationReceiptSpec` → `spec.sha256`); the gate re-hashes the
/// CURRENT source and exits 1 on divergence. A usecase set generated
/// from a since-edited entity is stale — it must not stay "green".
class UsecaseDriftChecker {
  const UsecaseDriftChecker();

  UsecaseDriftResult check({
    required String projectRoot,
    required String entity,
    required GenerationReceipt? receipt,
  }) {
    if (receipt == null) {
      return const UsecaseDriftResult(
        bound: false,
        drifted: false,
        detail:
            'no create receipt found — nothing to drift against '
            '(the surface is gated by conformance alone)',
      );
    }
    final spec = receipt.spec;
    if (spec == null) {
      return const UsecaseDriftResult(
        bound: true,
        drifted: false,
        detail:
            'the create receipt binds no entity source (the entity file '
            'did not exist at generation time) — no drift can be proven',
      );
    }
    final entityFile = File(
      p.isAbsolute(spec.path) ? spec.path : p.join(projectRoot, spec.path),
    );
    if (!entityFile.existsSync()) {
      return UsecaseDriftResult(
        bound: true,
        drifted: true,
        detail:
            'the entity source ${spec.path} was DELETED after generation '
            '(the receipt binds its hash ${spec.sha256.substring(0, 12)}…)',
        receiptSpecPath: spec.path,
        receiptHash: spec.sha256,
        currentHash: null,
      );
    }
    final currentHash = crypto.sha256
        .convert(entityFile.readAsBytesSync())
        .toString();
    if (currentHash != spec.sha256) {
      return UsecaseDriftResult(
        bound: true,
        drifted: true,
        detail:
            'the entity source ${spec.path} changed after generation '
            '(receipt binds ${spec.sha256.substring(0, 12)}…, current '
            '${currentHash.substring(0, 12)}…) — the usecase set is stale',
        receiptSpecPath: spec.path,
        receiptHash: spec.sha256,
        currentHash: currentHash,
      );
    }
    return UsecaseDriftResult(
      bound: true,
      drifted: false,
      detail: 'the entity source matches the receipt binding',
      receiptSpecPath: spec.path,
      receiptHash: spec.sha256,
      currentHash: currentHash,
    );
  }

  /// The conventional entity source path the create receipt binds
  /// (`lib/src/domain/entities/<snake>/<snake>.dart`).
  static String entitySourcePath(String entity) {
    final snake = StringUtils.camelToSnake(entity);
    return 'lib/src/domain/entities/$snake/$snake.dart';
  }
}

class UsecaseDriftResult {
  /// True when a receipt with an entity binding exists.
  final bool bound;

  /// True ONLY when a binding exists and the current source provably
  /// diverges from it (changed or deleted). Never a guess.
  final bool drifted;

  final String detail;
  final String? receiptSpecPath;
  final String? receiptHash;
  final String? currentHash;

  const UsecaseDriftResult({
    required this.bound,
    required this.drifted,
    required this.detail,
    this.receiptSpecPath,
    this.receiptHash,
    this.currentHash,
  });

  Map<String, dynamic> toJson() => {
    'bound': bound,
    'drifted': drifted,
    'detail': detail,
    if (receiptSpecPath != null) 'receiptSpecPath': receiptSpecPath,
    if (receiptHash != null) 'receiptHash': receiptHash,
    if (currentHash != null) 'currentHash': currentHash,
  };
}
