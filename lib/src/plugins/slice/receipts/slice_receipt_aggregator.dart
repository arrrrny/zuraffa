/// The slice receipt aggregator (spec 1116, issue #1116): the one
/// command, full audit behind `zfa slice verify <feature-id>`.
///
/// Reads the five sub-receipts the engine/skin pipeline wrote into the
/// slice (the issue's directory schema, tolerant of the specs/ mount
/// the worktree lanes actually write to) and aggregates them into
/// `slice.receipt.json`:
///
/// | section | source artifact                                   | producer |
/// |---------|---------------------------------------------------|----------|
/// | engine  | `engine/engine.receipt.json` (v2)                 | #1109    |
/// | cert    | `engine/mock-cert/mock-cert.<E>.json`             | #1001/#1110 |
/// | skin    | `skin/skin.receipt.json` (skin.v1)                | #1111    |
/// | xray    | the slice boundary audit (SliceCheck) + manifest  | #1114/#1115 |
/// | journal | `journal.json` (unified TDD journal)              | #1113    |
///
/// Verdict rule: `green` only when every section is green; exit 0 only
/// on green. Each red section names its violator and the EXACT re-run
/// command — the merge gate's fix path is machine-checkable, not prose
/// (the cert-gate refusal discipline, #1110).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../capabilities/slice_check_capability.dart';
import '../generators/feature_slice_composer.dart';
import '../models/feature_slice_manifest.dart';
import 'slice_receipt.dart';

/// The result of one `slice verify` aggregation.
class SliceReceiptAggregation {
  /// Whether the aggregation ran at all (a composed slice was found and
  /// the receipt was written). INV-1 failures (no slice) report here.
  final bool success;

  /// The one-line status the command prints.
  final String message;

  /// The whole-receipt verdict: green | red | pending.
  final String verdict;

  /// The aggregated receipt as written to disk.
  final Map<String, dynamic> receipt;

  /// Slice-root-relative path of the written receipt.
  final String? receiptPath;

  /// Per-section re-run commands (red sections only).
  final Map<String, String> rerun;

  const SliceReceiptAggregation({
    required this.success,
    required this.message,
    required this.verdict,
    required this.receipt,
    this.receiptPath,
    this.rerun = const {},
  });
}

/// Aggregates the five sub-receipts into the slice receipt.
class SliceReceiptAggregator {
  const SliceReceiptAggregator();

  /// Runs the full audit for [featureId]'s slice under [projectRoot].
  Future<SliceReceiptAggregation> aggregate({
    required String projectRoot,
    required String featureId,
  }) async {
    final sliceRoot = FeatureSliceComposer.sliceRootOf(projectRoot, featureId);
    final manifestFile = File(p.join(sliceRoot, 'slice.yaml'));
    if (!manifestFile.existsSync()) {
      return SliceReceiptAggregation(
        success: false,
        verdict: 'red',
        receipt: const {},
        message:
            'Feature "$featureId" has no composed slice — run '
            '`zfa slice compose $featureId` first (spec 1114).',
      );
    }

    final FeatureSliceManifest manifest;
    try {
      manifest = FeatureSliceManifest.fromYaml(manifestFile.readAsStringSync());
    } on Object {
      return SliceReceiptAggregation(
        success: false,
        verdict: 'red',
        receipt: const {},
        message:
            'The slice manifest at ${manifestFile.path} is corrupt — '
            're-run `zfa slice compose $featureId` (spec 1114).',
      );
    }

    // The contract is the entity/route truth (compose wrote it).
    final contract = _readContract(sliceRoot, manifest.contractFile);
    final contractEntities = contract?['entities'] as List? ?? const [];
    final contractRoutes = contract?['routes'] as List? ?? const [];

    final rerun = <String, String>{};

    // — 1. engine: the v2 engine receipt(s), #1109 —
    final engine = _aggregateEngine(sliceRoot, featureId, rerun);

    // — 2. cert: the per-entity mock certs against the contract, #1110 —
    final cert = _aggregateCert(
      sliceRoot,
      featureId,
      contractEntities.cast<String>(),
      rerun,
    );

    // — 3. skin: the skin lane receipt, #1111 —
    final skin = _aggregateSkin(
      sliceRoot,
      featureId,
      contractRoutes.cast<String>(),
      manifest,
      rerun,
    );

    // — 4. xray: the slice boundary audit (layer counts + violations) —
    final xray = await _aggregateXray(
      projectRoot: projectRoot,
      featureId: featureId,
      manifest: manifest,
      rerun: rerun,
    );

    // — 5. journal: the unified TDD journal verdict, #1113 —
    final journal = _aggregateJournal(sliceRoot, featureId, rerun);

    final verdict =
        (engine['status'] == 'green' &&
            cert['status'] == 'green' &&
            skin['status'] == 'green' &&
            xray['status'] == 'green' &&
            journal['status'] == 'green')
        ? 'green'
        : 'red';

    final receipt = <String, dynamic>{
      'schema': sliceReceiptSchema,
      'feature_id': featureId,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'verdict': verdict,
      'engine': engine,
      'skin': skin,
      'cert': cert,
      'xray': xray,
      'journal': journal,
      'rerun': rerun,
    };

    final path = await writeSliceReceipt(sliceRoot, receipt);

    final marks = {
      'engine': engine['status'] as String,
      'skin': skin['status'] as String,
      'cert': cert['status'] as String,
      'xray': xray['status'] as String,
      'journal': journal['status'] as String,
    };
    final line = [
      'slice $featureId: $verdict',
      for (final entry in marks.entries)
        '${entry.key} ${entry.value == 'green'
            ? "✅"
            : entry.value == "pending"
            ? "—"
            : "❌"}',
    ].join(' — ');

    final message = StringBuffer(line);
    for (final section in const ['engine', 'skin', 'cert', 'xray', 'journal']) {
      final sectionMap = receipt[section];
      if (sectionMap is! Map) continue;
      final detail = sectionMap['detail']?.toString();
      if (sectionMap['status'] == 'red' && detail != null) {
        message.write('\n  $section: $detail');
      }
      final command = rerun[section];
      if (command != null) {
        message.write('\n  re-run $section: $command');
      }
    }
    message.write(
      '\n  receipt: ${p.relative(path, from: projectRoot).replaceAll("\\", "/")}',
    );

    return SliceReceiptAggregation(
      success: true,
      message: message.toString(),
      verdict: verdict,
      receipt: receipt,
      receiptPath: path,
      rerun: rerun,
    );
  }

  // ------------------------------------------------------------------
  // engine (#1109)
  // ------------------------------------------------------------------

  /// Prefers the issue's slice layout (`engine/engine.receipt.json`),
  /// falls back to the specs mount the lane writes in the worktree
  /// (`specs/<id>/tdd/engine.receipt.json`). One receipt per entity
  /// (deterministic: the canonical name wins over numbered re-runs).
  List<({String entity, Map<String, dynamic> map})> _engineReceipts(
    String sliceRoot,
    String featureId,
  ) {
    for (final dir in [
      p.join(sliceRoot, 'engine'),
      p.join(sliceRoot, 'specs', featureId, 'tdd'),
    ]) {
      final receipts = _parseReceipts(_receiptFiles(dir, 'engine.receipt'));
      if (receipts.isNotEmpty) return receipts;
    }
    return const [];
  }

  Map<String, dynamic> _aggregateEngine(
    String sliceRoot,
    String featureId,
    Map<String, String> rerun,
  ) {
    final receipts = _engineReceipts(sliceRoot, featureId);
    if (receipts.isEmpty) {
      rerun['engine'] =
          'zfa make engine $featureId && zfa engine check $featureId';
      return {
        'status': 'red',
        'n_methods': 0,
        'n_mocks_certified': 0,
        'detail': 'no engine.receipt.json in engine/ or specs/$featureId/tdd/',
      };
    }
    var methods = 0;
    var certified = 0;
    String? offender;
    String? offenderClass;
    String? corrupt;
    for (final receipt in receipts) {
      final list = receipt.map['methods'] as List? ?? const [];
      for (final method in list) {
        if (method is! Map) continue;
        methods++;
        final ok = method['mock_certified'] == true;
        if (ok) certified++;
        if (!ok && offender == null) {
          offender = receipt.entity;
          offenderClass = method['mock_class']?.toString();
        }
      }
      if (receipt.map['schema'] != 'engine.receipt.v2' && corrupt == null) {
        corrupt = receipt.entity;
      }
    }
    if (offender != null) {
      rerun['engine'] = 'zfa engine check $offender';
    }
    return {
      'status': offender == null && corrupt == null && methods > 0
          ? 'green'
          : 'red',
      'n_methods': methods,
      'n_mocks_certified': certified,
      if (offender != null)
        'detail':
            'method mock_class "$offenderClass" is uncertified '
            '(entity $offender) — the CERT-GATE signal',
      if (corrupt != null)
        'detail':
            'receipt for "$corrupt" does not carry schema '
            'engine.receipt.v2',
    };
  }

  // ------------------------------------------------------------------
  // cert (#1001/#1110)
  // ------------------------------------------------------------------

  /// Cert receipts from every home the pipeline writes them to, deduped
  /// by entity (the issue's slice layout wins).
  Map<String, Map<String, dynamic>> _certReceipts(
    String sliceRoot,
    String featureId,
  ) {
    final byEntity = <String, Map<String, dynamic>>{};
    for (final dir in [
      p.join(sliceRoot, 'engine', 'mock-cert'),
      p.join(sliceRoot, 'specs', featureId, 'tdd', 'mock-cert'),
      p.join(sliceRoot, 'test', 'mock'),
    ]) {
      final root = Directory(dir);
      if (!root.existsSync()) continue;
      final files =
          root
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => p.basename(f.path).startsWith('mock-cert.'))
              .where((f) => f.path.endsWith('.json'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      for (final file in files) {
        try {
          final decoded = jsonDecode(file.readAsStringSync());
          if (decoded is! Map<String, dynamic>) continue;
          final entity = decoded['entity']?.toString();
          if (entity == null || entity.isEmpty) continue;
          // First home wins: the slice layout outranks the mounts.
          byEntity.putIfAbsent(entity, () => decoded);
        } on FormatException {
          continue;
        }
      }
    }
    return byEntity;
  }

  Map<String, dynamic> _aggregateCert(
    String sliceRoot,
    String featureId,
    List<String> contractEntities,
    Map<String, String> rerun,
  ) {
    final certs = _certReceipts(sliceRoot, featureId);
    final uncertified = <String>[];
    var differentialPassed = true;
    for (final entity in contractEntities) {
      final cert = certs[entity];
      if (cert == null) {
        uncertified.add(entity);
        continue;
      }
      final methods = cert['methods'] as List? ?? const [];
      final satisfied =
          methods.isNotEmpty &&
          methods.every((m) => m is Map && m['satisfied'] == true);
      if (!satisfied) uncertified.add(entity);
      final sandbox = cert['sandbox'] as Map? ?? const {};
      final failed = sandbox['tests_failed'];
      if (failed is int && failed > 0) differentialPassed = false;
    }
    if (uncertified.isNotEmpty) {
      rerun['cert'] = 'zfa mock certify ${uncertified.first}';
    } else if (!differentialPassed) {
      rerun['cert'] = contractEntities.isNotEmpty
          ? 'zfa mock certify ${contractEntities.first}'
          : 'zfa mock certify <entity>';
    }
    return {
      'status': uncertified.isEmpty && differentialPassed ? 'green' : 'red',
      'uncertified_entities': uncertified,
      'differential_passed': differentialPassed,
      'n_certs': certs.length,
      if (uncertified.isNotEmpty)
        'detail':
            'entities without a satisfied mock-cert: '
            '${uncertified.join(", ")}',
      if (!differentialPassed)
        'detail':
            'a certified mock failed its contract differential '
            '(sandbox tests_failed > 0)',
    };
  }

  // ------------------------------------------------------------------
  // skin (#1111)
  // ------------------------------------------------------------------

  Map<String, dynamic> _aggregateSkin(
    String sliceRoot,
    String featureId,
    List<String> contractRoutes,
    FeatureSliceManifest manifest,
    Map<String, String> rerun,
  ) {
    Map<String, dynamic>? receipt;
    String? source;
    for (final candidate in [
      p.join(sliceRoot, 'skin', 'skin.receipt.json'),
      p.join(sliceRoot, 'specs', featureId, 'tdd', '04-skin-receipt.json'),
    ]) {
      final file = File(candidate);
      if (!file.existsSync()) continue;
      try {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is Map<String, dynamic>) {
          receipt = decoded;
          source = p.relative(candidate, from: sliceRoot).replaceAll('\\', '/');
        }
      } on FormatException {
        receipt = null;
        source = null;
      }
      break;
    }

    if (receipt == null) {
      rerun['skin'] = 'zfa tdd run-skin $featureId';
      return {
        'status': 'red',
        'n_routes': contractRoutes.length,
        'n_contract_rows': 0,
        'n_platforms_audited': 0,
        'detail': 'no skin.receipt.json in skin/ or specs/$featureId/tdd/',
      };
    }

    final behaviors = receipt['behaviors'] as List? ?? const [];
    final conformed =
        behaviors.isNotEmpty &&
        behaviors.every((b) => b is Map && b['conformance'] == true);
    final platforms = receipt['platform_slot_fills'] as List? ?? const [];
    if (!conformed) {
      rerun['skin'] = 'zfa tdd run-skin $featureId';
    }
    return {
      'status': conformed ? 'green' : 'red',
      'n_routes': contractRoutes.isNotEmpty
          ? contractRoutes.length
          : manifest.skinRoutes.length,
      'n_contract_rows': receipt['contract_rows_audited'] is int
          ? receipt['contract_rows_audited'] as int
          : 0,
      'n_platforms_audited': platforms.length,
      'receipt': source,
      if (!conformed)
        'detail': behaviors.isEmpty
            ? 'the skin receipt records no conformed behaviors'
            : 'a skin behavior did not conform (skin.v1 conformance)',
    };
  }

  // ------------------------------------------------------------------
  // xray (#1114 check / #1115 layers)
  // ------------------------------------------------------------------

  Future<Map<String, dynamic>> _aggregateXray({
    required String projectRoot,
    required String featureId,
    required FeatureSliceManifest manifest,
    required Map<String, String> rerun,
  }) async {
    final enginePaths = manifest.engineFiles.map((f) => f.relativePath).toSet();
    final skinPaths = manifest.skinFiles.map((f) => f.relativePath).toSet();
    final shared = enginePaths.intersection(skinPaths);

    final check = await SliceCheckCapability().execute(
      projectRoot: projectRoot,
      featureId: featureId,
    );
    final violations = [for (final v in check.violations) v.toJson()];
    if (violations.isNotEmpty) {
      rerun['xray'] = 'zfa slice check $featureId';
    }
    return {
      'status': violations.isEmpty ? 'green' : 'red',
      'layers': {
        'engine': enginePaths.length,
        'skin': skinPaths.length,
        'shared': shared.length,
      },
      'violations': violations,
    };
  }

  // ------------------------------------------------------------------
  // journal (#1113)
  // ------------------------------------------------------------------

  Map<String, dynamic> _aggregateJournal(
    String sliceRoot,
    String featureId,
    Map<String, String> rerun,
  ) {
    Map<String, dynamic>? journal;
    String? source;
    for (final candidate in [
      p.join(sliceRoot, 'journal.json'),
      p.join(sliceRoot, 'specs', featureId, 'tdd', 'journal.json'),
    ]) {
      final file = File(candidate);
      if (!file.existsSync()) continue;
      try {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is Map<String, dynamic>) {
          journal = decoded;
          source = p.relative(candidate, from: sliceRoot).replaceAll('\\', '/');
        }
      } on FormatException {
        journal = null;
        source = null;
      }
      break;
    }

    if (journal == null) {
      rerun['journal'] = 'zfa tdd run $featureId';
      return {
        'status': 'red',
        'cycles': 0,
        'violations': 0,
        'final_state': 'absent',
        'detail':
            'no journal.json in the slice or its specs mount '
            '(spec 1113)',
      };
    }

    final entries = journal['entries'] as List? ?? const [];
    var violations = 0;
    for (final entry in entries) {
      if (entry is! Map) continue;
      violations += (entry['violations'] as List? ?? const []).length;
    }
    final finalState = entries.isNotEmpty && entries.last is Map
        ? (entries.last as Map)['gate_state']?.toString() ?? 'absent'
        : 'absent';
    final green =
        entries.isNotEmpty && finalState == 'green' && violations == 0;
    if (!green) {
      rerun['journal'] = 'zfa tdd run $featureId';
    }
    final section = <String, dynamic>{
      'status': green ? 'green' : 'red',
      'cycles': entries.length,
      'violations': violations,
      'final_state': finalState,
    };
    if (source != null) section['path'] = source;
    if (!green) {
      section['detail'] = entries.isEmpty
          ? 'the journal carries no cycle entries'
          : 'final gate_state "$finalState" with $violations violation(s)';
    }
    return section;
  }

  // ------------------------------------------------------------------
  // helpers
  // ------------------------------------------------------------------

  ({String entity, Map<String, dynamic> map})? _parseReceipt(File file) {
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) return null;
      return (
        entity: decoded['entity']?.toString() ?? p.basename(file.path),
        map: decoded,
      );
    } on FormatException {
      return null;
    }
  }

  /// The receipt files named `<base>.json` and `<base>-<n>.json` under
  /// [dir], canonical name first, numbered re-runs ascending.
  List<({String entity, Map<String, dynamic> map})> _parseReceipts(
    List<File> files,
  ) {
    final parsed = <({String entity, Map<String, dynamic> map})>[];
    for (final file in files) {
      final receipt = _parseReceipt(file);
      if (receipt != null) parsed.add(receipt);
    }
    // One receipt per entity: the canonical (unnumbered) file wins.
    final byEntity = <String, ({String entity, Map<String, dynamic> map})>{};
    for (final receipt in parsed) {
      byEntity.putIfAbsent(receipt.entity, () => receipt);
    }
    return byEntity.values.toList();
  }

  List<File> _receiptFiles(String dir, String base) {
    final root = Directory(dir);
    if (!root.existsSync()) return const [];
    return root.listSync().whereType<File>().where((f) {
      final name = p.basename(f.path);
      if (!name.endsWith('.json')) return false;
      if (name == '$base.json') return true;
      final numbered = RegExp('^$base-\\d+\\.json\$');
      return numbered.hasMatch(name);
    }).toList()..sort((a, b) {
      // Canonical first, then -2, -3 … ascending.
      int rank(String path) {
        final name = p.basenameWithoutExtension(path);
        final dash = name.lastIndexOf('-');
        if (dash < 0) return 0;
        final n = int.tryParse(name.substring(dash + 1));
        return n ?? 0;
      }

      final byRank = rank(a.path).compareTo(rank(b.path));
      if (byRank != 0) return byRank;
      return a.path.compareTo(b.path);
    });
  }

  Map<String, dynamic>? _readContract(String sliceRoot, String contractFile) {
    for (final candidate in [
      p.join(sliceRoot, contractFile),
      p.join(sliceRoot, 'contract.json'),
    ]) {
      final file = File(candidate);
      if (!file.existsSync()) continue;
      try {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is Map<String, dynamic>) return decoded;
      } on FormatException {
        return null;
      }
    }
    return null;
  }
}
