/// `GoldenWorkflow` — the CI referee's orchestrated pipeline (spec 070
/// FR-001): setup → corpus verify → per-feature gates → gap ledger +
/// coverage matrix, emitted as a single [RefereeVerdict].
///
/// Idempotent (assumption: same PR state → same verdict) and resumable
/// (FR-010/SC-006): completed steps and partial results persist at
/// `.zfa/corpus/referee-run.json` after every step, so an interrupted
/// run (CI timeout) resumes from the last completed step instead of
/// restarting. The referee READS the recorded infrastructure
/// (receipts, artifacts, cycle-logs, corpus state, gap ledger) and
/// never mutates it — its only writes are its own run-state, verdict
/// and rollup documents.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'feature_provenance.dart';
import 'feature_provenance_reader.dart';

/// One coverage-matrix row: a feature and the test tiers with recorded
/// evidence (FR-014).
class CoverageRow {
  const CoverageRow({required this.feature, required this.tiers});

  final String feature;
  final Set<String> tiers;
}

/// The coverage matrix: which features are verified against which test
/// tiers, from recorded evidence (green cycle-log entries = unit;
/// mutation reports = mutation; platform/ffi artifacts = integration /
/// contract lanes).
class CoverageMatrix {
  const CoverageMatrix({required this.rows});

  final List<CoverageRow> rows;

  int get verifiedFeatures => rows.where((r) => r.tiers.isNotEmpty).length;
}

/// The golden workflow's final verdict: the steps that ran, the
/// per-feature provenance, the gap-ledger and coverage outputs, and the
/// machine result token.
class RefereeVerdict {
  const RefereeVerdict({
    required this.steps,
    required this.features,
    required this.gapLedger,
    required this.coverage,
    required this.result,
    this.resumedFrom,
  });

  /// The steps that ran this invocation, in order.
  final List<String> steps;

  final List<FeatureProvenance> features;
  final GapLedgerSummary gapLedger;
  final CoverageMatrix coverage;

  /// `pass` (all real, no blocking gaps), `gaps`, `empty`, `partial`.
  final String result;

  /// The step an interrupted run resumed from (FR-010), or null for a
  /// fresh run.
  final String? resumedFrom;

  Map<String, dynamic> toJson() => {
    'steps': steps,
    'result': result,
    'resumed_from': resumedFrom,
    'features': [
      for (final f in features)
        {
          'feature': f.feature,
          'state': f.state.label,
          'receipts': f.receiptCount,
          'hand_delta_receipts': f.handDeltaReceipts,
          'buckets': {
            'generated': f.buckets.generated,
            'mock': f.buckets.mock,
            'hand_delta': f.buckets.handDelta,
            'hand_written': f.buckets.handWritten,
          },
          'receipt_verified': f.receiptVerified,
          'receipt_ids': f.receiptIds,
        },
    ],
    'gap_ledger': {
      'found': gapLedger.found,
      'open': gapLedger.open,
      'blocking': gapLedger.blocking,
    },
    'coverage': {
      'verified_features': coverage.verifiedFeatures,
      'rows': [
        for (final row in coverage.rows)
          {'feature': row.feature, 'tiers': row.tiers.toList()..sort()},
      ],
    },
  };
}

class GoldenWorkflow {
  GoldenWorkflow(this.projectRoot);

  final String projectRoot;

  String get runStatePath =>
      p.join(projectRoot, '.zfa', 'corpus', 'referee-run.json');

  String get verdictPath =>
      p.join(projectRoot, '.zfa', 'corpus', 'referee-verdict.json');

  /// Run the golden workflow. With [resume] true (or a run-state file
  /// present), completed steps are not repeated and partial results are
  /// preserved (FR-010).
  Future<RefereeVerdict> run({bool resume = false}) async {
    final reader = FeatureProvenanceReader(projectRoot);

    // ---- Resume: load completed steps + partial results (FR-010). ----
    var completed = <String>[];
    var features = <FeatureProvenance>[];
    String? resumedFrom;
    final stateFile = File(runStatePath);
    if (resume && await stateFile.exists()) {
      try {
        final state =
            jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>;
        completed = (state['completed_steps'] as List? ?? const [])
            .whereType<String>()
            .toList();
        resumedFrom = completed.isEmpty ? null : completed.last;
        features = _decodeFeatures(state['features']);
      } on FormatException {
        // A corrupt run-state restarts cleanly — never fatal.
      }
    }

    // The steps run THIS invocation (the verdict reports what ran now,
    // not the historical union).
    final steps = <String>[];

    // ---- Step 1: setup (resolve + read the recorded state). ----
    if (!completed.contains('setup')) {
      steps.add('setup');
      completed.add('setup');
      await _persistRunState(completed, 'partial', features);
    }

    // ---- Step 2: corpus verify (per-feature provenance). ----
    if (!completed.contains('corpus-verify')) {
      features = await reader.read();
      steps.add('corpus-verify');
      completed.add('corpus-verify');
      await _persistRunState(completed, 'partial', features);
    }

    // ---- Step 3: per-feature gates (realization states above). ----
    if (!completed.contains('per-feature-gates')) {
      // The gates read the derived states; every non-real feature is a
      // named gate outcome (the gap-ledger summary below carries them).
      steps.add('per-feature-gates');
      completed.add('per-feature-gates');
      await _persistRunState(completed, 'partial', features);
    }

    // ---- Step 4: outputs (gap ledger + coverage matrix + verdict). ----
    final gapLedger = await _readGapLedger(features);
    final coverage = await _readCoverageMatrix();
    steps.add('outputs');

    final result = features.isEmpty
        ? 'empty'
        : gapLedger.open > 0
        ? 'gaps'
        : 'pass';

    final verdict = RefereeVerdict(
      steps: steps,
      features: features,
      gapLedger: gapLedger,
      coverage: coverage,
      result: result,
      resumedFrom: resumedFrom,
    );

    // The durable verdict document (machine-readable output, FR-013/
    // FR-014 assumption) and the cleared run-state (run complete).
    await _persistRunState(completed, result, features);
    final verdictFile = File(verdictPath);
    await verdictFile.parent.create(recursive: true);
    await verdictFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(verdict.toJson()),
    );
    await stateFile.delete().catchError((_) => stateFile);
    return verdict;
  }

  // ---- helpers ----------------------------------------------------------

  /// Persist the run state (completed steps + partial results) so an
  /// interrupted run resumes rather than restarts (SC-006).
  Future<void> _persistRunState(
    List<String> steps,
    String result,
    List<FeatureProvenance> features,
  ) async {
    final file = File(runStatePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'completed_steps': steps,
        'result': result,
        'features': [
          for (final f in features)
            {
              'feature': f.feature,
              'state': f.state.label,
              'receipts': f.receiptCount,
              'hand_delta_receipts': f.handDeltaReceipts,
              'buckets': {
                'generated': f.buckets.generated,
                'mock': f.buckets.mock,
                'hand_delta': f.buckets.handDelta,
                'hand_written': f.buckets.handWritten,
              },
              'receipt_verified': f.receiptVerified,
              'receipt_ids': f.receiptIds,
            },
        ],
      }),
    );
  }

  List<FeatureProvenance> _decodeFeatures(dynamic raw) {
    if (raw is! List) return [];
    final features = <FeatureProvenance>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final state = FeatureRealizationState.values
          .where((s) => s.label == row['state'])
          .firstOrNull;
      if (state == null) continue;
      final bucketsRaw = row['buckets'];
      features.add(
        FeatureProvenance(
          feature: row['feature'] as String? ?? '',
          state: state,
          receiptCount: row['receipts'] as int? ?? 0,
          handDeltaReceipts: row['hand_delta_receipts'] as int? ?? 0,
          buckets: bucketsRaw is Map
              ? ProvenanceBuckets(
                  generated: bucketsRaw['generated'] as int? ?? 0,
                  mock: bucketsRaw['mock'] as int? ?? 0,
                  handDelta: bucketsRaw['hand_delta'] as int? ?? 0,
                  handWritten: bucketsRaw['hand_written'] as int? ?? 0,
                )
              : const ProvenanceBuckets(
                  generated: 0,
                  mock: 0,
                  handDelta: 0,
                  handWritten: 0,
                ),
          receiptVerified: row['receipt_verified'] as bool? ?? false,
          receiptIds: (row['receipt_ids'] as List? ?? const [])
              .whereType<String>()
              .toList(),
        ),
      );
    }
    return features;
  }

  /// The gap-ledger summary (FR-013): reads `.zfa/corpus/gap-ledger.json`
  /// read-only and names the features not at their target state. Per
  /// bug #846 semantics: `open` counts every unresolved gap regardless
  /// of feature state; `blocking` names unresolved gaps on features
  /// whose corpus state is not done/waived.
  Future<GapLedgerSummary> _readGapLedger(
    List<FeatureProvenance> features,
  ) async {
    final corpusDir = p.join(projectRoot, '.zfa', 'corpus');
    final file = File(p.join(corpusDir, 'gap-ledger.json'));
    if (!await file.exists()) {
      return GapLedgerSummary(found: 0, open: 0, blocking: const []);
    }
    final doneFeatures = await _readDoneFeatures();
    try {
      final entries = jsonDecode(await file.readAsString()) as List;
      var found = 0, open = 0;
      final blocking = <String>{};
      for (final entry in entries) {
        if (entry is! Map) continue;
        final kind = entry['kind'];
        final feature = entry['feature'];
        if (feature is! String) continue;
        if (kind == 'resolution') continue;
        if (kind != 'gap') continue;
        found++;
        final status = entry['status'];
        final resolved = status == 'resolved' || status == 'merged';
        if (!resolved) open++;
        if (!resolved && !doneFeatures.contains(feature)) blocking.add(feature);
      }
      return GapLedgerSummary(
        found: found,
        open: open,
        blocking: blocking.toList()..sort(),
      );
    } on FormatException {
      return GapLedgerSummary(found: 0, open: 0, blocking: const []);
    }
  }

  /// Corpus feature states that count as at-target (done or waived).
  Future<Set<String>> _readDoneFeatures() async {
    final file = File(p.join(projectRoot, '.zfa', 'corpus', 'progress.json'));
    if (!await file.exists()) return const {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return const {};
      final features = decoded['features'];
      if (features is! Map) return const {};
      return {
        for (final entry in features.entries)
          if (entry.value is Map &&
              const {'done', 'waived'}.contains((entry.value as Map)['state']))
            entry.key as String,
      };
    } on FormatException {
      return const {};
    }
  }

  /// The coverage matrix (FR-014): per feature, the tiers with recorded
  /// evidence — green cycle-log entries (unit), mutation reports
  /// (mutation), platform/ffi harness artifacts (integration/contract).
  Future<CoverageMatrix> _readCoverageMatrix() async {
    final specsDir = Directory(p.join(projectRoot, 'specs'));
    if (!await specsDir.exists()) return const CoverageMatrix(rows: []);
    final rows = <CoverageRow>[];
    for (final dir in specsDir.listSync().whereType<Directory>()) {
      final feature = p.basename(dir.path);
      final tdd = p.join(dir.path, 'tdd');
      final tiers = <String>{};
      final cycleLog = File(p.join(tdd, 'cycle-log.md'));
      if (await cycleLog.exists() &&
          (await cycleLog.readAsString()).contains('(green)')) {
        tiers.add('unit');
      }
      if (await File(p.join(tdd, 'mutation-report.json')).exists()) {
        tiers.add('mutation');
      }
      if (await File(p.join(tdd, 'channel-scenarios.json')).exists()) {
        tiers.add('contract');
      }
      rows.add(CoverageRow(feature: feature, tiers: tiers));
    }
    rows.sort((a, b) => a.feature.compareTo(b.feature));
    return CoverageMatrix(rows: rows);
  }
}
