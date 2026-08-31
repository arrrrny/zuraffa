/// `zfa tdd corpus run` — drive every `ready` feature in the corpus
/// manifest through `zfa tdd run` then `zfa tdd verify`, in manifest
/// order (spec 051-corpus-harness, FR-001..FR-004).
///
/// The loop (mirroring `zfa tdd run`'s honesty rules one level up):
/// - Corpus progress persists after every feature; a run interrupted for
///   minutes or weeks resumes from the first non-done/waived feature and
///   never re-drives completed features.
/// - STOP-ON-ROADBLOCK (FR-002): any feature-level stop (run failure or
///   a non-passing verify gate without an exact-match waiver) halts the
///   whole run non-zero, appends a gap-ledger entry with the six FR-007
///   fields, and no later feature starts.
/// - A feature counts as corpus-done ONLY on a passing gate or an
///   explicit recorded waiver (reason + actor + timestamp) — never a
///   silent absorption (FR-004).
/// - Not-ready features are skipped and reported, never spawned
///   (FR-003); they block completion (reported, not driven).
/// - The runner writes only progress + ledger: never specs/, lib/,
///   test/, the manifest, waivers, or the carve-out.
///
/// Machine contract (FR-009/FR-010): every feature prints
/// `[corpus] <feature> <step> -> <outcome>`, and every invocation ends
/// with the final summary line
/// `corpus: features=<n> done=<n> waived=<n> stopped=<n> not_ready=<n>
/// pending=<n> dropped=<n> gaps=<n> result=<r>` plus ` stopped_at=<f>`
/// when stopped. Exit codes: 0 complete (every manifest feature done or
/// waived), 1 stopped/incomplete, 2 runner-error incl. no-manifest,
/// 3 corrupt-state, 4 concurrent-run.
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
import '../services/corpus_step_runner.dart';
import '../services/gap_ledger_store.dart';

class CorpusRunCommand extends Command<void> {
  CorpusRunCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root of the driven app (containing .zfa/, specs/, lib/). '
          'When omitted, the current working directory is used. The runner '
          'never mutates the process-global working directory.',
    );
    argParser.addOption(
      'zfa-bin',
      help:
          'Path to the zfa CLI entrypoint used to spawn the per-feature '
          '`tdd run` / `tdd verify` commands (defaults to this package\'s '
          'bin/zfa.dart). Point this at a scripted fake to drive the corpus '
          'against stubbed features.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'run';

  @override
  String get description =>
      'Drive every ready manifest feature through run then verify in '
      'manifest order, stopping on the first roadblock (spec 051, '
      'FR-001..FR-004).';

  @override
  String get invocation =>
      'zfa tdd corpus run [--project <dir>] [--zfa-bin <path>]';

  static const _exitComplete = 0;
  static const _exitStopped = 1;
  static const _exitRunnerError = 2;
  static const _exitCorruptState = 3;
  static const _exitConcurrentRun = 4;

  @override
  Future<void> run() async {
    final argResults = this.argResults;
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : Directory.current.path;
    final zfaBin = argResults?['zfa-bin'] as String?;

    final manifestStore = CorpusManifestStore(projectRoot);
    final progressStore = CorpusProgressStore(projectRoot);
    final ledgerStore = GapLedgerStore(projectRoot);

    // -----------------------------------------------------------------
    // 1. The manifest (no-manifest is the distinct runner-error class).
    // -----------------------------------------------------------------
    final CorpusManifest manifest;
    final List<CorpusWaiver> waivers;
    try {
      manifest = await manifestStore.readManifest();
      waivers = await manifestStore.readWaivers();
    } on CorpusManifestMissingException catch (e) {
      print('zfa tdd corpus run: ${e.message}');
      _printSummary(features: 0, result: 'no-manifest');
      exitCode = _exitRunnerError;
      return;
    } on CorpusCorruptException catch (e) {
      print('zfa tdd corpus run: ${e.message}');
      _printSummary(features: 0, result: 'corrupt-state');
      exitCode = _exitCorruptState;
      return;
    } on CorpusManifestException catch (e) {
      print('zfa tdd corpus run: ${e.message}');
      _printSummary(features: 0, result: 'corrupt-state');
      exitCode = _exitCorruptState;
      return;
    }

    // -----------------------------------------------------------------
    // 2. Progress: load (corrupt stops with the recovery path) and the
    //    concurrent-run refusal (FR-010) — no writes before both pass.
    // -----------------------------------------------------------------
    final CorpusProgress progress;
    try {
      progress = await progressStore.load() ?? CorpusProgress();
    } on CorpusCorruptException catch (e) {
      print('zfa tdd corpus run: ${e.message}');
      _printSummary(features: manifest.features.length, result: 'corrupt-state');
      exitCode = _exitCorruptState;
      return;
    }
    final refusal = progressStore.refusalReason(progress);
    if (refusal != null) {
      print('zfa tdd corpus run: $refusal');
      _printSummary(
        features: manifest.features.length,
        result: 'concurrent-run',
        progress: progress,
        manifest: manifest,
      );
      exitCode = _exitConcurrentRun;
      return;
    }

    final manifestNames = manifest.features.map((f) => f.name).toSet();
    print(
      'zfa tdd corpus run: ${manifest.features.length} feature(s) '
      '(${manifest.features.where((f) => !f.ready).length} not-ready)',
    );

    // -----------------------------------------------------------------
    // 3. Drive in manifest order (FR-001); STOP-ON-ROADBLOCK (FR-002).
    // -----------------------------------------------------------------
    final runner = CorpusStepRunner(zfaBin: zfaBin);
    String? stoppedAtFeature;

    Future<void> persist() => progressStore.save(
      progress,
      manifestFeatureNames: manifestNames,
    );

    for (final feature in manifest.features) {
      final name = feature.name;
      final existing = progress.features[name];

      // Resume: done/waived features are never re-driven (US1.AC2).
      if (existing?.state == FeatureCorpusState.done ||
          existing?.state == FeatureCorpusState.waived) {
        continue;
      }

      // Not-ready: skipped and reported, never spawned (FR-003).
      if (!feature.ready) {
        print(
          '[corpus] $name not-ready (${feature.reason.isEmpty ? 'no reason recorded' : feature.reason}) '
          '-- skipped, never driven',
        );
        continue;
      }

      // mark -> save -> spawn -> advance -> save: an interruption loses
      // at most the in-flight feature (the 049 contract, one level up).
      progress.updateFeature(
        name,
        FeatureProgress(state: FeatureCorpusState.driving),
      );
      progress.inFlight = CorpusInFlight(feature: name, ownerPid: pid);
      await persist();

      // --- zfa tdd run <feature> ---
      final runResult = await runner.runFeature(
        feature: name,
        projectRoot: projectRoot,
      );
      print('[corpus] $name run -> ${runResult.outcome}');
      if (!runResult.success) {
        await _stopAtFeature(
          feature: name,
          step: 'run',
          outcome: runResult.outcome,
          stoppedAt: runResult.stoppedAt,
          gate: null,
          failingCommand: _runCommand(name, projectRoot),
          output: runResult.output,
          progress: progress,
          ledgerStore: ledgerStore,
          persist: persist,
        );
        stoppedAtFeature = name;
        break;
      }

      // --- zfa tdd verify --feature <feature> ---
      final verifyResult = await runner.verifyFeature(
        feature: name,
        projectRoot: projectRoot,
      );
      print('[corpus] $name verify -> ${verifyResult.outcome}');

      if (verifyResult.success) {
        progress.updateFeature(
          name,
          FeatureProgress(state: FeatureCorpusState.done, gate: 'pass'),
        );
        print('[corpus] $name -> done (gate: pass)');
        // A previously-gapped feature passing records the resolution as
        // NEW ledger entries — history is never edited (US4.AC2).
        await _appendResolutionsIfGapped(
          feature: name,
          ledgerStore: ledgerStore,
        );
      } else {
        // Exact-match waiver only (FR-004): a waiver for a different
        // gate outcome never absorbs this failure.
        final waiver = waivers
            .where((w) => w.feature == name && w.gate == verifyResult.outcome)
            .firstOrNull;
        if (waiver != null) {
          progress.updateFeature(
            name,
            FeatureProgress(
              state: FeatureCorpusState.waived,
              gate: verifyResult.outcome,
              waiver: waiver,
            ),
          );
          print(
            '[corpus] $name -> waived (gate: ${verifyResult.outcome}; '
            'reason: ${waiver.reason}; by ${waiver.actor} at ${waiver.at})',
          );
        } else {
          await _stopAtFeature(
            feature: name,
            step: 'verify',
            outcome: verifyResult.outcome,
            stoppedAt: 'gate:${verifyResult.outcome}',
            gate: verifyResult.outcome,
            failingCommand: _verifyCommand(name, projectRoot),
            output: verifyResult.output,
            progress: progress,
            ledgerStore: ledgerStore,
            persist: persist,
          );
          stoppedAtFeature = name;
          break;
        }
      }
      progress.inFlight = null;
      await persist();
    }

    // -----------------------------------------------------------------
    // 4. Final report + the machine summary line (FR-008/FR-009).
    // -----------------------------------------------------------------
    final ledger = await _loadLedgerQuietly(ledgerStore);
    final doneFeatures = progress.features.entries
        .where(
          (e) =>
              e.value.state == FeatureCorpusState.done ||
              e.value.state == FeatureCorpusState.waived,
        )
        .map((e) => e.key)
        .toSet();
    final totals = GapLedgerTotals.fromEntries(
      ledger,
      doneFeatures: doneFeatures,
    );

    _printReport(manifest: manifest, progress: progress, totals: totals);
    final result = stoppedAtFeature != null
        ? 'stopped'
        : _complete(manifest, progress)
        ? 'complete'
        : 'incomplete';
    _printSummary(
      features: manifest.features.length,
      result: result,
      progress: progress,
      manifest: manifest,
      gaps: totals.found,
      stoppedAt: stoppedAtFeature,
    );

    exitCode = result == 'complete' ? _exitComplete : _exitStopped;
  }

  /// Every manifest feature is done or waived (not-ready features block
  /// completion — they are reported, never silently absorbed).
  static bool _complete(CorpusManifest manifest, CorpusProgress progress) {
    for (final feature in manifest.features) {
      if (!feature.ready) return false;
      final state = progress.features[feature.name]?.state;
      if (state != FeatureCorpusState.done &&
          state != FeatureCorpusState.waived) {
        return false;
      }
    }
    return true;
  }

  /// STOP-ON-ROADBLOCK bookkeeping (FR-002 + FR-007): ledger entry,
  /// stopped progress state, in-flight cleared, persist.
  Future<void> _stopAtFeature({
    required String feature,
    required String step,
    required String outcome,
    required String? stoppedAt,
    required String? gate,
    required String failingCommand,
    required String output,
    required CorpusProgress progress,
    required GapLedgerStore ledgerStore,
    required Future<void> Function() persist,
  }) async {
    final behavior = stoppedAt?.contains(':') == true
        ? stoppedAt!.split(':').first
        : null;
    await ledgerStore.appendGap(
      feature: feature,
      behavior: behavior,
      step: step,
      outcome: outcome,
      failingCommand: failingCommand,
    );
    progress.updateFeature(
      feature,
      FeatureProgress(
        state: FeatureCorpusState.stopped,
        gate: gate,
        stoppedAt: stoppedAt,
      ),
    );
    progress.inFlight = null;
    await persist();
    print('zfa tdd corpus run: stopped at $feature ($step: $outcome)');
    print('   ${_firstLines(output, 3)}');
    print('   resume: fix the roadblock, then re-run `zfa tdd corpus run`');
  }

  /// Resolution entries for a previously-gapped feature that just passed
  /// (US4.AC2): one NEW entry per unresolved gap, never an edit.
  Future<void> _appendResolutionsIfGapped({
    required String feature,
    required GapLedgerStore ledgerStore,
  }) async {
    final ledger = await _loadLedgerQuietly(ledgerStore);
    final resolvedIds = ledger
        .where((e) => e.kind == GapLedgerKind.resolution)
        .map((e) => e.resolves)
        .whereType<String>()
        .toSet();
    for (final gap in ledger) {
      if (gap.kind != GapLedgerKind.gap) continue;
      if (gap.feature != feature) continue;
      if (gap.status == 'resolved' || gap.status == 'merged') continue;
      if (resolvedIds.contains(gap.id)) continue;
      await ledgerStore.appendResolution(feature: feature, resolves: gap.id);
      print('[corpus] $feature gap ${gap.id} resolved (new ledger entry)');
    }
  }

  static Future<List<GapLedgerEntry>> _loadLedgerQuietly(
    GapLedgerStore store,
  ) async {
    try {
      return await store.load();
    } on CorpusCorruptException {
      // The ledger is append-only history; if it is corrupt the stop
      // surfaces elsewhere (the load gate in a next invocation). Here
      // the report degrades to empty totals rather than crashing mid-run.
      return const [];
    }
  }

  static String _runCommand(String feature, String projectRoot) =>
      'zfa tdd run $feature --project $projectRoot';

  static String _verifyCommand(String feature, String projectRoot) =>
      'zfa tdd verify --feature $feature --project $projectRoot';

  static String _firstLines(String output, int count) {
    final lines = output
        .split('\n')
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .take(count);
    return lines.isEmpty ? '(no output)' : lines.join(' | ');
  }

  /// The human report above the summary line (US4.AC3, FR-008).
  void _printReport({
    required CorpusManifest manifest,
    required CorpusProgress progress,
    required GapLedgerTotals totals,
  }) {
    final done = <String>[];
    final waived = <String>[];
    final stopped = <String>[];
    final pending = <String>[];
    final notReady = <String>[];
    for (final feature in manifest.features) {
      final state = progress.features[feature.name]?.state;
      switch (state) {
        case FeatureCorpusState.done:
          done.add(feature.name);
        case FeatureCorpusState.waived:
          waived.add(feature.name);
        case FeatureCorpusState.stopped:
          stopped.add(feature.name);
        case null:
        case FeatureCorpusState.pending:
        case FeatureCorpusState.driving:
          if (!feature.ready) {
            notReady.add('${feature.name} (${feature.reason})');
          } else {
            pending.add(feature.name);
          }
      }
    }
    print('--- corpus report ---');
    if (done.isNotEmpty) print('   done (${done.length}): ${done.join(', ')}');
    if (waived.isNotEmpty) {
      print('   waived (${waived.length}):');
      for (final name in waived) {
        final w = progress.features[name]?.waiver;
        print(
          '      $name — ${w?.gate ?? '?'}: ${w?.reason ?? '?'} '
          '(by ${w?.actor ?? '?'}, at ${w?.at ?? '?'})',
        );
      }
    }
    if (stopped.isNotEmpty) {
      print('   stopped (${stopped.length}): ${stopped.join(', ')}');
    }
    if (notReady.isNotEmpty) {
      print('   not-ready (${notReady.length}): ${notReady.join(', ')}');
    }
    if (pending.isNotEmpty) {
      print('   pending (${pending.length}): ${pending.join(', ')}');
    }
    if (progress.dropped.isNotEmpty) {
      print('   dropped (${progress.dropped.length}): ${progress.dropped.join(', ')}');
    }
    print(
      '   ledger: found=${totals.found} filed=${totals.filed} '
      'merged=${totals.merged} blocking=${totals.blocking.length}',
    );
    for (final gap in totals.blocking) {
      print(
        '   blocking: ${gap.id} ${gap.feature} ${gap.step} ${gap.outcome}'
        '${gap.behavior != null ? ' (${gap.behavior})' : ''}',
      );
    }
  }

  void _printSummary({
    required int features,
    required String result,
    CorpusProgress? progress,
    CorpusManifest? manifest,
    int gaps = 0,
    String? stoppedAt,
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
      '${stoppedAt != null ? ' stopped_at=$stoppedAt' : ''}',
    );
  }
}
