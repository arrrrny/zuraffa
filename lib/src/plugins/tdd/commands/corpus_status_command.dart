/// `zfa tdd corpus status` — read-only corpus state at a glance (spec
/// 051-corpus-harness, FR-009): per-state feature counts, gate outcomes,
/// the resume point, and ledger totals from the manifest + progress +
/// ledger + waivers — driving nothing, writing nothing.
///
/// Machine contract: ends with
/// `corpus: features=<n> done=<n> waived=<n> stopped=<n> not_ready=<n>
/// pending=<n> dropped=<n> gaps=<n> result=<complete|incomplete|
/// corrupt-state|no-manifest>[ resume_at=<feature>]`. Exit 0 exactly
/// when every manifest feature is done or waived AND the ledger holds
/// no open gaps (bug #846: open gaps refuse a `complete` verdict);
/// 1 incomplete; 2 no-manifest (usage-level runner error); 3
/// corrupt-state.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../tdd_plugin.dart';
import '../models/corpus_ledger.dart';
import '../models/corpus_manifest.dart';
import '../models/corpus_progress.dart';
import '../services/corpus_manifest_store.dart';
import '../services/corpus_progress_store.dart';
import '../services/gap_ledger_store.dart';
import '../../../core/project/project_root.dart';

class CorpusStatusCommand extends Command<void> {
  CorpusStatusCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root of the driven app (containing .zfa/, specs/, lib/). '
          'When omitted, the current working directory is used.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'status';

  @override
  String get description =>
      'Report corpus state read-only: per-state counts, resume point, '
      'ledger totals (spec 051, FR-009).';

  @override
  String get invocation => 'zfa tdd corpus status [--project <dir>]';

  static const _exitComplete = 0;
  static const _exitIncomplete = 1;
  static const _exitRunnerError = 2;
  static const _exitCorruptState = 3;

  @override
  Future<void> run() async {
    final argResults = this.argResults;
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');

    final manifestStore = CorpusManifestStore(projectRoot);
    final progressStore = CorpusProgressStore(projectRoot);
    final ledgerStore = GapLedgerStore(projectRoot);

    // -----------------------------------------------------------------
    // 1. Manifest (read-only; the distinct outcome classes).
    // -----------------------------------------------------------------
    final CorpusManifest manifest;
    final List<CorpusWaiver> waivers;
    try {
      manifest = await manifestStore.readManifest();
      waivers = await manifestStore.readWaivers();
    } on CorpusManifestMissingException catch (e) {
      print('zfa tdd corpus status: ${e.message}');
      _printSummary(features: 0, result: 'no-manifest');
      exitCode = _exitRunnerError;
      return;
    } on CorpusCorruptException catch (e) {
      print('zfa tdd corpus status: ${e.message}');
      _printSummary(features: 0, result: 'corrupt-state');
      exitCode = _exitCorruptState;
      return;
    } on CorpusManifestException catch (e) {
      print('zfa tdd corpus status: ${e.message}');
      _printSummary(features: 0, result: 'corrupt-state');
      exitCode = _exitCorruptState;
      return;
    }

    // -----------------------------------------------------------------
    // 2. Progress + ledger (read-only; corrupt stops with recovery).
    // -----------------------------------------------------------------
    final CorpusProgress progress;
    final List<GapLedgerEntry> ledger;
    try {
      progress = await progressStore.load() ?? CorpusProgress();
      ledger = await ledgerStore.load();
    } on CorpusCorruptException catch (e) {
      print('zfa tdd corpus status: ${e.message}');
      _printSummary(
        features: manifest.features.length,
        result: 'corrupt-state',
      );
      exitCode = _exitCorruptState;
      return;
    }

    // -----------------------------------------------------------------
    // 3. Aggregate + report (US5.AC1: counts, resume point, totals).
    // -----------------------------------------------------------------
    var done = 0;
    var waived = 0;
    var stopped = 0;
    var notReady = 0;
    var pending = 0;
    String? resumeAt;
    final doneFeatures = <String>{};
    final waiversByFeature = {for (final w in waivers) w.feature: w};

    for (final feature in manifest.features) {
      final state = progress.features[feature.name]?.state;
      if (state == FeatureCorpusState.done ||
          state == FeatureCorpusState.waived) {
        doneFeatures.add(feature.name);
      }
      if (!feature.ready) {
        notReady++;
      } else {
        switch (state) {
          case FeatureCorpusState.done:
            done++;
          case FeatureCorpusState.waived:
            waived++;
          case FeatureCorpusState.stopped:
            stopped++;
          case null:
          case FeatureCorpusState.pending:
          case FeatureCorpusState.driving:
            pending++;
        }
      }
      // The resume point: the first non-done/waived feature in manifest
      // order (what `corpus run` would drive next).
      if (resumeAt == null &&
          feature.ready &&
          state != FeatureCorpusState.done &&
          state != FeatureCorpusState.waived) {
        resumeAt = feature.name;
      }
    }

    final totals = GapLedgerTotals.fromEntries(
      ledger,
      doneFeatures: doneFeatures,
    );

    // The human report.
    print('--- corpus status ---');
    for (final feature in manifest.features) {
      final entry = progress.features[feature.name];
      final stateEnum = entry?.state;
      final state = stateEnum?.name ?? 'pending';
      final gate = entry?.gate;
      final waiver = entry?.waiver;
      print(
        '   ${feature.name}: $state'
        '${gate != null ? ' (gate: $gate)' : ''}'
        '${!feature.ready ? ' [not-ready: ${feature.reason}]' : ''}',
      );
      if (waiver != null) {
        print(
          '      waived: ${waiver.reason} (by ${waiver.actor}, '
          'at ${waiver.at})',
        );
      } else if (waiversByFeature.containsKey(feature.name) &&
          stateEnum != FeatureCorpusState.waived) {
        // A recorded waiver whose gate has not been evaluated yet.
        final w = waiversByFeature[feature.name]!;
        print(
          '      waiver on file: ${w.gate} — ${w.reason} '
          '(by ${w.actor}, at ${w.at})',
        );
      }
    }
    if (progress.dropped.isNotEmpty) {
      print(
        '   dropped (${progress.dropped.length}): '
        '${progress.dropped.join(', ')}',
      );
    }
    print(
      '   ledger: found=${totals.found} filed=${totals.filed} '
      'merged=${totals.merged} blocking=${totals.blocking.length}',
    );
    for (final gap in totals.blocking) {
      print('   blocking: ${gap.id} ${gap.feature} ${gap.step} ${gap.outcome}');
    }

    // Per-feature coverage (bug #846): complete/total from the plan's
    // traceability artifact, when the feature was planned through the
    // coverage gate. Features planned before the gate simply have no
    // line — reported, never invented.
    for (final feature in manifest.features) {
      final coverage = _traceabilityCoverage(projectRoot, feature.name);
      if (coverage != null) {
        print(
          '   coverage: ${feature.name} '
          '${coverage.complete}/${coverage.total} '
          '(manual: ${coverage.manual})',
        );
      }
    }

    final openGapRefusal = totals.open.isNotEmpty;
    if (openGapRefusal) {
      // Bug #846: open gaps refuse a `complete` verdict even when every
      // feature is done/waived — reported, never silently absorbed.
      print(
        '   open gaps: ${totals.open.length} — corpus refuses '
        '`complete` while gaps are open:',
      );
      for (final gap in totals.open) {
        print(
          '   open gap: ${gap.id} ${gap.feature} ${gap.step} ${gap.outcome}',
        );
      }
    }
    final complete =
        notReady == 0 &&
        pending == 0 &&
        stopped == 0 &&
        done + waived == manifest.features.length &&
        !openGapRefusal;

    _printSummary(
      features: manifest.features.length,
      result: complete ? 'complete' : 'incomplete',
      progress: progress,
      manifest: manifest,
      gaps: totals.found,
      resumeAt: resumeAt,
    );
    exitCode = complete ? _exitComplete : _exitIncomplete;
  }

  void _printSummary({
    required int features,
    required String result,
    CorpusProgress? progress,
    CorpusManifest? manifest,
    int gaps = 0,
    String? resumeAt,
  }) {
    var done = 0;
    var waived = 0;
    var stopped = 0;
    var notReady = 0;
    var pending = 0;
    if (manifest != null) {
      for (final feature in manifest.features) {
        final state = progress?.features[feature.name]?.state;
        if (!feature.ready) {
          notReady++;
        } else {
          switch (state) {
            case FeatureCorpusState.done:
              done++;
            case FeatureCorpusState.waived:
              waived++;
            case FeatureCorpusState.stopped:
              stopped++;
            case null:
            case FeatureCorpusState.pending:
            case FeatureCorpusState.driving:
              pending++;
          }
        }
      }
    }
    final dropped = progress?.dropped.length ?? 0;
    print(
      'corpus: features=$features done=$done waived=$waived stopped=$stopped '
      'not_ready=$notReady pending=$pending dropped=$dropped gaps=$gaps '
      'result=$result'
      '${resumeAt != null ? ' resume_at=$resumeAt' : ''}',
    );
  }

  /// Per-feature coverage counts from the plan's traceability artifact
  /// (`specs/<feature>/tdd/traceability.md`), or null when the feature
  /// has no traceability plan (pre-gate features are reported as such —
  /// never invented).
  static _FeatureCoverage? _traceabilityCoverage(
    String projectRoot,
    String feature,
  ) {
    final file = File(
      p.join(projectRoot, 'specs', feature, 'tdd', 'traceability.md'),
    );
    if (!file.existsSync()) return null;
    final content = file.readAsStringSync();
    final match = RegExp(r'statements:\s*(\d+)').firstMatch(content);
    final manual = RegExp(r'manual:\s*(\d+)').firstMatch(content);
    if (match == null || manual == null) return null;
    final total = int.parse(match.group(1)!);
    final manualCount = int.parse(manual.group(1)!);
    return _FeatureCoverage(
      total: total,
      complete: total - manualCount,
      manual: manualCount,
    );
  }
}

class _FeatureCoverage {
  const _FeatureCoverage({
    required this.total,
    required this.complete,
    required this.manual,
  });

  final int total;
  final int complete;
  final int manual;
}
