/// `FeatureProvenanceReader` — derives per-feature provenance (spec 070)
/// from the recorded infrastructure, read-only:
///
/// - #807 receipt ledger (`.zfa/receipts/`) — file digests for drift
///   detection (hand-delta) and receipt verification.
/// - 044 artifact registries (`specs/*/tdd/artifacts.json`) — the
///   feature → subject-file attribution.
/// - cycle-log evidence (`specs/*/tdd/cycle-log.md`) — green behaviors.
/// - #832 simulation fixture manifests
///   (`specs/*/tdd/fixtures/manifest.json`) — the mocked binding.
/// - 051 corpus progress (`.zfa/corpus/progress.json`) — `driving` marks
///    the intermediate `realizing` state.
///
/// State derivation (priority order):
/// 1. feature with registered subjects but NO receipt covering any of
///    them → `receipt-unknown` (FR-009 — corrupt receipts are skipped by
///    the store, which lands here too);
/// 2. no green evidence at all → `pending`;
/// 3. corpus state `driving` or partially-green behaviors → `realizing`
///    (FR-015);
/// 4. all behaviors green + simulation fixture manifest →
///    `complete(mocked)`;
/// 5. all behaviors green + no simulation binding → `complete(real)`.
///
/// Unfeatureized `lib/` files (registered to no feature) roll into the
/// `shared` row — infrastructure code, never a gap (spec edge case).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../../core/project/receipt_store.dart';
import 'feature_provenance.dart';

class FeatureProvenanceReader {
  FeatureProvenanceReader(this.projectRoot);

  /// The driven app's project root.
  final String projectRoot;

  /// Read every feature's provenance plus the `shared` row for
  /// non-featureized `lib/` code. Returns an empty list for an empty
  /// corpus (edge case) — never throws for absent evidence.
  Future<List<FeatureProvenance>> read() async {
    final records = await ReceiptStore(projectRoot: projectRoot).loadAll();

    // Latest-wins index: the most recent receipt entry per path (records
    // are oldest-first, so the LAST hit wins). Two PRs landing receipts
    // in quick succession resolve to the latest state (spec edge case).
    final latestByPath = <String, ReceiptRecord>{};
    for (final record in records) {
      for (final entry in record.receipt.files) {
        latestByPath[entry.path] = record;
      }
    }

    // The receipt file entry per path (digest source).
    final entryByPath = <String, GenerationReceiptFile>{};
    for (final record in records) {
      for (final entry in record.receipt.files) {
        entryByPath[entry.path] = entry;
      }
    }

    final features = <FeatureProvenance>[];
    final attributed = <String>{};

    // ---- Per-feature: the specs/ walk. ----
    final specsDir = Directory(p.join(projectRoot, 'specs'));
    if (await specsDir.exists()) {
      final featureDirs =
          specsDir
              .listSync()
              .whereType<Directory>()
              .map((d) => p.basename(d.path))
              .toList()
            ..sort();
      final corpusStates = await _readCorpusStates();
      for (final feature in featureDirs) {
        final subjects = await _readSubjectPaths(feature);
        if (subjects.isEmpty) continue; // not a TDD-driven feature
        subjects.forEach(attributed.add);
        features.add(
          await _deriveFeature(
            feature,
            subjects,
            latestByPath: latestByPath,
            entryByPath: entryByPath,
            corpusState: corpusStates[feature],
          ),
        );
      }
    }

    // ---- The shared/infrastructure row: every other lib/ file. ----
    final shared = await _deriveShared(attributed, entryByPath);
    if (shared != null) features.add(shared);

    return features;
  }

  /// The feature's registered subject paths from its artifacts registry
  /// (044). Malformed registries are skipped (reported as empty).
  Future<Set<String>> _readSubjectPaths(String feature) async {
    final registry = File(
      p.join(projectRoot, 'specs', feature, 'tdd', 'artifacts.json'),
    );
    if (!await registry.exists()) return const {};
    try {
      final decoded = jsonDecode(await registry.readAsString());
      if (decoded is! Map) return const {};
      final records = decoded['records'];
      if (records is! List) return const {};
      return {
        for (final record in records)
          if (record is Map && record['subject_path'] is String)
            p.posix.normalize(record['subject_path'] as String),
      };
    } on FormatException {
      return const {};
    }
  }

  /// Behavior ids with green cycle-log evidence for [feature].
  Future<Set<String>> _readGreenBehaviors(String feature) async {
    final cycleLog = File(
      p.join(projectRoot, 'specs', feature, 'tdd', 'cycle-log.md'),
    );
    if (!await cycleLog.exists()) return const {};
    final greens = <String>{};
    final lines = (await cycleLog.readAsString()).split('\n');
    var currentBehavior = '';
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('## Cycle:')) {
        // `## Cycle: <behavior> (green|red|refactor)`
        final header = trimmed.substring('## Cycle:'.length).trim();
        currentBehavior = header.split(' ').first;
      } else if (trimmed.startsWith('- kind:') &&
          trimmed.endsWith('green') &&
          currentBehavior.isNotEmpty) {
        greens.add(currentBehavior);
      }
    }
    return greens;
  }

  /// All behavior ids registered for [feature] (the driven universe).
  Future<Set<String>> _readBehaviorIds(String feature) async {
    final registry = File(
      p.join(projectRoot, 'specs', feature, 'tdd', 'artifacts.json'),
    );
    if (!await registry.exists()) return const {};
    try {
      final decoded = jsonDecode(await registry.readAsString());
      if (decoded is! Map) return const {};
      final records = decoded['records'];
      if (records is! List) return const {};
      return {
        for (final record in records)
          if (record is Map && record['behavior_id'] is String)
            record['behavior_id'] as String,
      };
    } on FormatException {
      return const {};
    }
  }

  /// Corpus progress feature states (051), feature name → state token.
  Future<Map<String, String>> _readCorpusStates() async {
    final file = File(p.join(projectRoot, '.zfa', 'corpus', 'progress.json'));
    if (!await file.exists()) return const {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return const {};
      final features = decoded['features'];
      if (features is! Map) return const {};
      return {
        for (final entry in features.entries)
          if (entry.value is Map && (entry.value as Map)['state'] is String)
            entry.key as String: (entry.value as Map)['state'] as String,
      };
    } on FormatException {
      return const {};
    }
  }

  /// Whether [feature] is bound to the certified simulation world (#832):
  /// a committed fixtures manifest exists.
  Future<bool> _hasSimulationBinding(String feature) => File(
    p.join(projectRoot, 'specs', feature, 'tdd', 'fixtures', 'manifest.json'),
  ).exists();

  Future<FeatureProvenance> _deriveFeature(
    String feature,
    Set<String> subjects, {
    required Map<String, ReceiptRecord> latestByPath,
    required Map<String, GenerationReceiptFile> entryByPath,
    String? corpusState,
  }) async {
    final behaviors = await _readBehaviorIds(feature);
    final greens = await _readGreenBehaviors(feature);
    final simulated = await _hasSimulationBinding(feature);

    // ---- The receipt buckets (SC-002: every count traces to receipts). ----
    var generated = 0, mock = 0, handDelta = 0, handWritten = 0;
    final receiptIds = <String>{};
    var handDeltaReceipts = 0;
    for (final rel in subjects) {
      final record = latestByPath[rel];
      final entry = entryByPath[rel];
      if (record == null || entry == null) {
        // A registered subject existing on disk but unprovenanced is
        // hand-written evidence for the ratio denominator.
        handWritten++;
        continue;
      }
      receiptIds.add(record.fileName);
      final matches = await _matchesReceipt(rel, entry);
      if (!matches) {
        handDelta++;
        handDeltaReceipts++;
      } else if (simulated) {
        mock++;
      } else {
        generated++;
      }
    }

    // ---- The realization state (priority order, see library docs). ----
    FeatureRealizationState state;
    final covered = receiptIds.isNotEmpty;
    if (!covered) {
      state = FeatureRealizationState.receiptUnknown;
    } else if (greens.isEmpty) {
      state = FeatureRealizationState.pending;
    } else if (corpusState == 'driving' ||
        (behaviors.isNotEmpty && !behaviors.every(greens.contains))) {
      state = FeatureRealizationState.realizing;
    } else if (simulated) {
      state = FeatureRealizationState.completeMocked;
    } else {
      state = FeatureRealizationState.completeReal;
    }

    return FeatureProvenance(
      feature: feature,
      state: state,
      receiptCount: receiptIds.length,
      handDeltaReceipts: handDeltaReceipts,
      buckets: ProvenanceBuckets(
        generated: generated,
        mock: mock,
        handDelta: handDelta,
        handWritten: handWritten,
      ),
      receiptVerified: handWritten == 0 && covered,
      receiptIds: receiptIds.toList()..sort(),
    );
  }

  // ---- shared row + digest helpers -----------------------------------

  Future<FeatureProvenance?> _deriveShared(
    Set<String> attributed,
    Map<String, GenerationReceiptFile> entryByPath,
  ) async {
    final libDir = Directory(p.join(projectRoot, 'lib'));
    if (!await libDir.exists()) return null;
    final libFiles = <String>[];
    await for (final entity in libDir.list(recursive: true)) {
      if (entity is File) {
        libFiles.add(
          p.posix.normalize(p.relative(entity.path, from: projectRoot)),
        );
      }
    }
    final unattributed = libFiles.where((f) => !attributed.contains(f)).toList()
      ..sort();
    if (unattributed.isEmpty) return null;

    var generated = 0, mock = 0, handDelta = 0, handWritten = 0;
    for (final rel in unattributed) {
      final entry = entryByPath[rel];
      if (entry == null) {
        handWritten++;
        continue;
      }
      if (await _matchesReceipt(rel, entry)) {
        generated++;
      } else {
        handDelta++;
      }
    }
    return FeatureProvenance(
      feature: 'shared',
      state: FeatureRealizationState.completeReal,
      receiptCount: unattributed.where(entryByPath.containsKey).length,
      handDeltaReceipts: handDelta,
      buckets: ProvenanceBuckets(
        generated: generated,
        mock: mock,
        handDelta: handDelta,
        handWritten: handWritten,
      ),
      receiptVerified: handWritten == 0,
      receiptIds: const [],
    );
  }

  /// Whether the on-disk bytes at [rel] still match the receipt digest.
  Future<bool> _matchesReceipt(String rel, GenerationReceiptFile entry) async {
    final file = File(p.join(projectRoot, rel));
    if (!await file.exists()) return entry.action == 'delete';
    final digest = sha256.convert(await file.readAsBytes()).toString();
    return digest == entry.sha256;
  }
}
