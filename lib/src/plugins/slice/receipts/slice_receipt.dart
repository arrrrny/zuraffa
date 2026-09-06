/// The slice receipt (spec 1116, issue #1116): the per-slice aggregation
/// the engine/skin split was missing — ONE artifact that says "this
/// feature is engine-green + skin-green + cert-passing + xray-clean +
/// journal-clean, ready to merge."
///
/// The receipt lives at `.zfa/slices/<feature-id>/slice.receipt.json`
/// and aggregates the five sub-receipts the pipeline writes:
///
/// - `engine`  — the engine lane receipt (spec 1110/#1109: the v2
///   `engine.receipt.json` with per-method `mock_certified` flags);
/// - `skin`    — the skin lane receipt (skin.v1, #1005/#1111);
/// - `cert`    — the per-entity mock certs (`mock-cert.<Entity>.json`,
///   #1001/#1110) checked against the contract's entities;
/// - `xray`    — the slice boundary audit (#1114 check / #1115 xray:
///   layer counts + violations);
/// - `journal` — the unified TDD journal (#1113: cycles, violations,
///   final gate state).
///
/// Lifecycle: `zfa slice compose` writes the empty SKELETON (every
/// section `pending`); running engine + skin + cert + xray in the slice
/// worktree fills the sub-receipts; `zfa slice verify` aggregates them
/// into the receipt and is the MERGE GATE — exit 0 only when every
/// section is green.
///
/// Section status vocabulary: `pending` (skeleton — the sub-receipt has
/// not been produced yet), `green` (the sub-receipt exists and passes),
/// `red` (it exists and fails, or is missing). The whole-receipt
/// `verdict` is `green` only when every section is green.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The receipt's schema tag.
const String sliceReceiptSchema = 'slice.receipt.v1';

/// Section/whole status vocabulary.
const Set<String> sliceReceiptStatuses = {'pending', 'green', 'red'};

/// The slice receipt's canonical file name inside the slice root.
const String sliceReceiptFileName = 'slice.receipt.json';

/// The stable slice id for an input feature id (spec 1116, requirement
/// 1): the slug normalization — trim, lowercase, underscores/spaces →
/// dashes, repeated separators collapsed, leading/trailing dashes
/// stripped. A pure function of the input, so it is stable across
/// re-compositions; the declared FeatureContract id (spec 1098)
/// outranks it when a contract resolves.
String slugFeatureId(String raw) {
  var slug = raw.trim().toLowerCase();
  slug = slug.replaceAll(RegExp(r'[\s_]+'), '-');
  slug = slug.replaceAll(RegExp(r'-{2,}'), '-');
  while (slug.startsWith('-')) {
    slug = slug.substring(1);
  }
  while (slug.endsWith('-')) {
    slug = slug.substring(0, slug.length - 1);
  }
  return slug;
}

/// The empty skeleton `zfa slice compose` writes: every section
/// `pending`, the whole verdict `pending`. `zfa slice verify` replaces
/// it with the aggregation.
Map<String, dynamic> sliceReceiptSkeleton(String featureId) => {
  'schema': sliceReceiptSchema,
  'feature_id': featureId,
  'generated_at': DateTime.now().toUtc().toIso8601String(),
  'verdict': 'pending',
  'engine': {'status': 'pending', 'n_methods': 0, 'n_mocks_certified': 0},
  'skin': {
    'status': 'pending',
    'n_routes': 0,
    'n_contract_rows': 0,
    'n_platforms_audited': 0,
  },
  'cert': {
    'status': 'pending',
    'uncertified_entities': <String>[],
    'differential_passed': true,
  },
  'xray': {
    'status': 'pending',
    'layers': {'engine': 0, 'skin': 0, 'shared': 0},
    'violations': <Map<String, dynamic>>[],
  },
  'journal': {
    'status': 'pending',
    'cycles': 0,
    'violations': 0,
    'final_state': 'absent',
  },
  'rerun': <String, String>{},
};

/// Write [receipt] to `<sliceRoot>/slice.receipt.json` — atomically
/// (temp + rename, the same discipline the journal and the v2 engine
/// receipt use): a crashed verify never leaves a half-written receipt.
Future<String> writeSliceReceipt(
  String sliceRoot,
  Map<String, dynamic> receipt,
) async {
  final file = File(p.join(sliceRoot, sliceReceiptFileName));
  await file.parent.create(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  final tmp = File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
  await tmp.writeAsString('${encoder.convert(receipt)}\n');
  await tmp.rename(file.path);
  return file.path;
}

/// Read the slice receipt for [sliceRoot], or null when compose has not
/// written one (a legacy cut slice, or a pre-1116 composition).
Map<String, dynamic>? readSliceReceipt(String sliceRoot) {
  final file = File(p.join(sliceRoot, sliceReceiptFileName));
  if (!file.existsSync()) return null;
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map<String, dynamic>) return decoded;
  } on FormatException {
    // A corrupt receipt reads as absent — verify rewrites it.
  } on FileSystemException {
    // Unreadable at read time — same honest-absent treatment.
  }
  return null;
}
