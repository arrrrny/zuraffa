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
///
/// The feature part is COLLISION-RESISTANT: a feature whose name folds
/// the same way as another feature's (`004-login/ui` vs `004-login-ui`)
/// carries a digest of the original name behind a `~` separator, so two
/// distinct features can never land on one receipt path.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
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
  /// The feature is encoded collision-resistantly ([_encodeSegment]), so
  /// two features whose names fold to the same text still land on
  /// different paths. The feature is REQUIRED and must be non-empty: the
  /// empty case would fall back to the shared feature-less name — the
  /// exact collision issue #1997 reports — so it is refused instead of
  /// silently allowed.
  static String fileNameFor(String behaviorId, {required String feature}) {
    _requireFeature(feature);
    final id = _sanitize(_stripContractPrefix(behaviorId));
    return 'contract-blocked.${_encodeSegment(feature)}.$id.json';
  }

  /// The LEGACY (pre-#1997) receipt file name for [behaviorId] — the
  /// feature-less name a pre-fix run left behind.
  ///
  /// Built EXPLICITLY, never through [fileNameFor]'s (removed)
  /// no-feature branch: the legacy path is a FROZEN contract — every
  /// pre-#1997 receipt on every project sits at this exact name and
  /// [readWithPath] still adopts it — so it must not move when the
  /// namespaced naming ever changes.
  static String legacyFileNameFor(String behaviorId) =>
      'contract-blocked.${_sanitize(_stripContractPrefix(behaviorId))}.json';

  /// The receipt's path for [behaviorId] in [feature].
  String pathFor(String behaviorId, {required String feature}) =>
      p.join(directory.path, fileNameFor(behaviorId, feature: feature));

  /// The LEGACY (pre-#1997) receipt path for [behaviorId] — the
  /// feature-less name a pre-fix run left behind.
  String legacyPathFor(String behaviorId) =>
      p.join(directory.path, legacyFileNameFor(behaviorId));

  /// Reads the receipt of [behaviorId] for [feature] TOGETHER WITH the
  /// path it was read FROM: the namespaced path first, then the LEGACY
  /// feature-less path — but only when the legacy receipt's own
  /// `feature` field names [feature]. A legacy receipt another feature
  /// wrote is NEVER adopted: that shared path is exactly the collision
  /// issue #1997 reports.
  ///
  /// The path is part of the answer because the caller prints it: a
  /// legacy receipt is adopted under its feature-less name, so the
  /// namespaced path is not always the file that answered.
  ContractBlockedReceiptRead? readWithPath({
    required String behaviorId,
    required String feature,
  }) {
    _requireFeature(feature);
    final namespacedPath = pathFor(behaviorId, feature: feature);
    final namespaced = ContractBlockedReceipt.fromFile(namespacedPath);
    // The owner check is not academic: it is what keeps a receipt another
    // feature wrote from being adopted for this one when two names fold
    // to the same text — the same guard the legacy read below carries.
    if (namespaced != null && namespaced.feature == feature) {
      return ContractBlockedReceiptRead(
        receipt: namespaced,
        path: namespacedPath,
      );
    }
    final legacyPath = legacyPathFor(behaviorId);
    final legacy = ContractBlockedReceipt.fromFile(legacyPath);
    if (legacy == null || legacy.feature != feature) return null;
    return ContractBlockedReceiptRead(receipt: legacy, path: legacyPath);
  }

  /// Reads the receipt of [behaviorId] for [feature] — see
  /// [readWithPath], which also reports the path the receipt came from.
  ContractBlockedReceipt? read({
    required String behaviorId,
    required String feature,
  }) => readWithPath(behaviorId: behaviorId, feature: feature)?.receipt;

  /// Persist [receipt] for its behavior id; returns the file path. The
  /// receipt's OWN feature names the file (issue #1997).
  ///
  /// Refuses to overwrite a receipt the path already holds for ANOTHER
  /// feature: the name is derived from the feature, so a mismatch means
  /// two features still landed on one path — the collision this store
  /// exists to prevent — and writing would silently destroy the other
  /// feature's verdict again.
  Future<String> write(ContractBlockedReceipt receipt) async {
    _requireFeature(receipt.feature, name: 'receipt.feature');
    await directory.create(recursive: true);
    final path = pathFor(receipt.behavior, feature: receipt.feature);
    final existing = ContractBlockedReceipt.fromFile(path);
    if (existing != null &&
        existing.feature.isNotEmpty &&
        existing.feature != receipt.feature) {
      throw StateError(
        'refusing to overwrite the contract-blocked receipt at $path: it '
        'belongs to feature "${existing.feature}", not '
        '"${receipt.feature}" (issue #1997)',
      );
    }
    await File(path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(receipt.toJson()),
    );
    return path;
  }

  static void _requireFeature(String feature, {String name = 'feature'}) {
    if (feature.isEmpty) {
      throw ArgumentError.value(
        feature,
        name,
        'must not be empty — a feature-less receipt lands on the shared '
        'feature-less path, the exact collision issue #1997 reports',
      );
    }
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
      segment.replaceAll(_nonPortable, '-');

  /// A COLLISION-RESISTANT file-name encoding of [segment].
  ///
  /// A segment that is already portable is kept verbatim — a feature
  /// named `004-login-ui` reads as `004-login-ui`, exactly as the
  /// namespacing contract above promises. A segment that is not is first
  /// folded to `-`, which is LOSSY (`004-login/ui` and `004-login-ui`
  /// fold to the same text), so the folded form carries the ORIGINAL
  /// segment's digest behind a `~` separator: `~` is itself
  /// non-portable, so a folded segment can never be confused with a
  /// verbatim one, and two folded segments differ unless their digests
  /// do.
  static String _encodeSegment(String segment) {
    if (!_nonPortable.hasMatch(segment)) return segment;
    final digest = crypto.sha256.convert(utf8.encode(segment)).toString();
    return '${_sanitize(segment)}~${digest.substring(0, 12)}';
  }

  /// The characters a receipt file name may carry (`~` is deliberately
  /// NOT among them — it is [_encodeSegment]'s folded-name separator).
  static final RegExp _nonPortable = RegExp(r'[^A-Za-z0-9_.-]');
}

/// A receipt read from disk together with the path it was read FROM —
/// the path is what a caller must report: a legacy (pre-#1997) receipt
/// is adopted under its feature-less name, so the namespaced path is not
/// always the file that answered.
class ContractBlockedReceiptRead {
  const ContractBlockedReceiptRead({required this.receipt, required this.path});

  /// The receipt payload.
  final ContractBlockedReceipt receipt;

  /// The absolute path the receipt was read from.
  final String path;
}
