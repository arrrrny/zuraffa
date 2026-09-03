/// `ProvenanceRollupBuilder` — the corpus-wide and per-feature provenance
/// rollup (spec 070 US2, FR-003): generated/mock/hand-delta ratios, all
/// verified against the #807 receipt ledger (SC-002), archived for
/// historical comparison on regeneration (FR-012).
///
/// Corpus ratios are feature-level (US2.AC1: "10 features, 8 generated, 1
/// hand-delta, 1 hand-written → 80%/10%/10%"); per-feature rows carry the
/// file-level receipt buckets and the receipt ids that back them
/// (US2.AC2: the audit trail behind every ratio).
///
/// Persisted at `.zfa/corpus/provenance-rollup.json` (assumption: a
/// persistent location, not ephemeral). Regeneration moves the previous
/// document into `.zfa/corpus/provenance-archive/` (FR-012).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'feature_provenance.dart';
import 'feature_provenance_reader.dart';

/// Corpus-wide ratio summary (feature-level, per US2.AC1).
class CorpusRatios {
  const CorpusRatios({
    required this.totalFeatures,
    required this.generatedFeatures,
    required this.handDeltaFeatures,
    required this.handWrittenFeatures,
    required this.mockPercent,
    required this.generatedPercent,
    required this.handDeltaPercent,
    required this.handWrittenPercent,
  });

  final int totalFeatures;
  final int generatedFeatures;
  final int handDeltaFeatures;
  final int handWrittenFeatures;
  final int mockPercent;
  final int generatedPercent;
  final int handDeltaPercent;
  final int handWrittenPercent;

  Map<String, dynamic> toJson() => {
    'total_features': totalFeatures,
    'generated_features': generatedFeatures,
    'hand_delta_features': handDeltaFeatures,
    'hand_written_features': handWrittenFeatures,
    'generated_percent': generatedPercent,
    'mock_percent': mockPercent,
    'hand_delta_percent': handDeltaPercent,
    'hand_written_percent': handWrittenPercent,
  };
}

/// The rollup document: corpus ratios + per-feature rows + the audit
/// trail.
class ProvenanceRollup {
  const ProvenanceRollup({
    required this.corpus,
    required this.perFeature,
    required this.receiptVerified,
    required this.path,
    required this.isEmpty,
    this.archivedFrom,
  });

  final CorpusRatios corpus;
  final List<FeatureProvenance> perFeature;
  final bool receiptVerified;
  final String path;
  final bool isEmpty;

  /// The previous rollup's JSON document when this run archived one
  /// (FR-012).
  final Map<String, dynamic>? archivedFrom;

  Map<String, dynamic> toJson() => {
    'corpus': corpus.toJson(),
    'per_feature': [
      for (final feature in perFeature)
        {
          'feature': feature.feature,
          'state': feature.state.label,
          'receipts': feature.receiptCount,
          'hand_delta_receipts': feature.handDeltaReceipts,
          'buckets': {
            'generated': feature.buckets.generated,
            'mock': feature.buckets.mock,
            'hand_delta': feature.buckets.handDelta,
            'hand_written': feature.buckets.handWritten,
          },
          'receipt_verified': feature.receiptVerified,
          'receipt_ids': feature.receiptIds,
        },
    ],
    'receipt_verified': receiptVerified,
    'empty': isEmpty,
  };
}

class ProvenanceRollupBuilder {
  ProvenanceRollupBuilder(this.projectRoot);

  final String projectRoot;

  String get rollupPath =>
      p.join(projectRoot, '.zfa', 'corpus', 'provenance-rollup.json');

  Directory get archiveDir =>
      Directory(p.join(projectRoot, '.zfa', 'corpus', 'provenance-archive'));

  /// Build (and persist) the rollup, archiving any previous document.
  /// Reads the recorded infrastructure read-only; the only writes are
  /// the rollup document and the archive of its predecessor.
  Future<ProvenanceRollup> build() async {
    final reader = FeatureProvenanceReader(projectRoot);
    final features = await reader.read();
    // The rollup's scope: driven features only (the `shared` row is a
    // verdict-table concern, not a corpus ratio feature).
    final driven = features.where((f) => f.feature != 'shared').toList();

    final generated = driven
        .where(
          (f) =>
              f.state == FeatureRealizationState.completeReal &&
              f.buckets.handDelta == 0,
        )
        .length;
    final handDelta = driven
        .where(
          (f) =>
              f.buckets.handDelta > 0 &&
              f.state != FeatureRealizationState.receiptUnknown,
        )
        .length;
    final handWritten = driven
        .where((f) => f.state == FeatureRealizationState.receiptUnknown)
        .length;
    final mocked = driven
        .where((f) => f.state == FeatureRealizationState.completeMocked)
        .length;

    final total = driven.length;
    final mockPercent = total == 0 ? 0 : (mocked * 100 / total).round();
    final generatedPercent = total == 0 ? 0 : (generated * 100 / total).round();
    final handDeltaPercent = total == 0 ? 0 : (handDelta * 100 / total).round();
    final handWrittenPercent = total == 0
        ? 0
        : (handWritten * 100 / total).round();

    final receiptVerified =
        driven.isNotEmpty &&
        driven.every((f) => f.state != FeatureRealizationState.receiptUnknown);

    // ---- FR-012: archive the previous rollup before overwriting. ----
    Map<String, dynamic>? archived;
    final rollupFile = File(rollupPath);
    if (await rollupFile.exists()) {
      try {
        archived =
            jsonDecode(await rollupFile.readAsString()) as Map<String, dynamic>;
        await archiveDir.create(recursive: true);
        final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
          ':',
          '-',
        );
        await File(
          p.join(archiveDir.path, 'rollup-$stamp.json'),
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(archived));
      } on FormatException {
        // A corrupt previous rollup is skipped, never fatal.
      }
    }

    final rollup = ProvenanceRollup(
      corpus: CorpusRatios(
        totalFeatures: total,
        generatedFeatures: generated,
        handDeltaFeatures: handDelta,
        handWrittenFeatures: handWritten,
        mockPercent: mockPercent,
        generatedPercent: generatedPercent,
        handDeltaPercent: handDeltaPercent,
        handWrittenPercent: handWrittenPercent,
      ),
      perFeature: driven,
      receiptVerified: receiptVerified,
      path: rollupPath,
      isEmpty: total == 0,
      archivedFrom: archived,
    );

    await rollupFile.parent.create(recursive: true);
    await rollupFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(rollup.toJson()),
    );
    return rollup;
  }
}
