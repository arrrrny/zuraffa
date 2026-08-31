/// Corpus runner service (spec 051-corpus-harness, FR-001..FR-004).
///
/// Orchestrates per-feature `zfa tdd run` → `zfa tdd verify` via sub-process
/// spawning, with STOP-ON-ROADBLOCK at corpus granularity.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/corpus_feature_progress.dart';
import '../models/gap_ledger_entry.dart';
import 'corpus_progress_store.dart';
import 'gap_ledger.dart';

/// Outcome of driving one feature through the corpus loop.
class FeatureOutcome {
  const FeatureOutcome({
    required this.name,
    required this.state,
    this.gateOutcome,
    this.stoppedAt,
    this.error,
  });

  final String name;
  final CorpusFeatureState state;
  final String? gateOutcome;
  final String? stoppedAt;
  final String? error;
}

/// Corpus runner — drives features through run→verify.
class CorpusRunner {
  CorpusRunner({
    required this.projectRoot,
    required this.progressStore,
    required this.gapLedger,
    this.zfaBin,
  });

  final String projectRoot;
  final CorpusProgressStore progressStore;
  final GapLedger gapLedger;
  final String? zfaBin;

  String get _zfaBin =>
      zfaBin ?? p.join(projectRoot, 'bin', 'zfa.dart');

  /// Run the corpus: drive each ready feature through run→verify.
  ///
  /// Returns the list of feature outcomes in order.
  Future<List<FeatureOutcome>> run({
    required List<String> manifestFeatures,
    required Map<String, bool> readiness,
  }) async {
    final outcomes = <FeatureOutcome>[];

    // Load or create progress.
    var progress = await progressStore.load() ?? CorpusProgress();

    // Resume point.
    // Set in-flight marker.
    progress = CorpusProgress(
      features: progress.features,
      inFlight: true,
      ownerPid: pid,
      startedAt: DateTime.now().toUtc().toIso8601String(),
      lastUpdatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await progressStore.save(progress);

    try {
      for (final featureName in manifestFeatures) {
        // Skip not-ready features.
        if (readiness[featureName] == false) {
          final featureProgress = CorpusFeatureProgress(
            name: featureName,
            state: CorpusFeatureState.notReady,
          );
          progress.features[featureName] = featureProgress;
          await progressStore.save(progress);
          outcomes.add(FeatureOutcome(
            name: featureName,
            state: CorpusFeatureState.notReady,
          ));
          continue;
        }

        // Skip already-done, dropped, or waived features.
        final existing = progress.features[featureName];
        if (existing?.state == CorpusFeatureState.done ||
            existing?.state == CorpusFeatureState.dropped ||
            existing?.state == CorpusFeatureState.waived) {
          outcomes.add(FeatureOutcome(
            name: featureName,
            state: existing!.state,
          ));
          continue;
        }

        // Mark driving.
        progress.features[featureName] = CorpusFeatureProgress(
          name: featureName,
          state: CorpusFeatureState.driving,
        );
        progress = CorpusProgress(
          features: progress.features,
          inFlight: true,
          ownerPid: pid,
          startedAt: progress.startedAt,
          lastUpdatedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await progressStore.save(progress);

        // Step 1: zfa tdd run <feature>
        final runResult = await _spawnZfa([
          'tdd', 'run', featureName,
          '--project', projectRoot,
        ]);

        if (runResult.exitCode != 0) {
          // STOP: run failed.
          progress.features[featureName] = CorpusFeatureProgress(
            name: featureName,
            state: CorpusFeatureState.stopped,
            gateOutcome: 'run-failed',
          );
          await progressStore.save(progress);

          await gapLedger.append(GapLedgerEntry(
            feature: featureName,
            outcome: 'stopped',
            command: 'zfa tdd run $featureName --project $projectRoot',
            timestamp: DateTime.now().toUtc().toIso8601String(),
          ));

          outcomes.add(FeatureOutcome(
            name: featureName,
            state: CorpusFeatureState.stopped,
            stoppedAt: 'run',
            error: '${runResult.stdout}\n${runResult.stderr}',
          ));
          break; // STOP-ON-ROADBLOCK
        }

        // Step 2: zfa tdd verify --feature <feature>
        final verifyResult = await _spawnZfa([
          'tdd', 'verify',
          '--feature', featureName,
          '--project', projectRoot,
        ]);

        final gateOutcome = _parseGateOutcome(verifyResult.stdout as String);

        if (verifyResult.exitCode == 0 && gateOutcome == 'PASS') {
          // Gate passed.
          progress.features[featureName] = CorpusFeatureProgress(
            name: featureName,
            state: CorpusFeatureState.done,
            gateOutcome: 'PASS',
          );
          await progressStore.save(progress);

          // Check if this was previously stopped — record resolution.
          if (existing?.state == CorpusFeatureState.stopped) {
            await gapLedger.appendResolution(
              feature: featureName,
              timestamp: DateTime.now().toUtc().toIso8601String(),
            );
          }

          outcomes.add(FeatureOutcome(
            name: featureName,
            state: CorpusFeatureState.done,
            gateOutcome: 'PASS',
          ));
        } else {
          // Gate failed.
          progress.features[featureName] = CorpusFeatureProgress(
            name: featureName,
            state: CorpusFeatureState.stopped,
            gateOutcome: gateOutcome ?? 'unknown',
          );
          await progressStore.save(progress);

          await gapLedger.append(GapLedgerEntry(
            feature: featureName,
            step: 'verify',
            outcome: gateOutcome ?? 'unknown',
            command: 'zfa tdd verify --feature $featureName --project $projectRoot',
            timestamp: DateTime.now().toUtc().toIso8601String(),
          ));

          outcomes.add(FeatureOutcome(
            name: featureName,
            state: CorpusFeatureState.stopped,
            stoppedAt: 'verify',
            gateOutcome: gateOutcome,
            error: '${verifyResult.stdout}\n${verifyResult.stderr}',
          ));
          break; // STOP-ON-ROADBLOCK
        }
      }
    } finally {
      // Clear in-flight marker.
      progress = CorpusProgress(
        features: progress.features,
        inFlight: false,
        lastUpdatedAt: DateTime.now().toUtc().toIso8601String(),
      );
      await progressStore.save(progress);
    }

    return outcomes;
  }

  /// Parse the gate outcome from verify command output.
  String? _parseGateOutcome(String output) {
    for (final line in output.split('\n')) {
      if (line.startsWith('mutation: gate=')) {
        final match = RegExp(r'gate=(\w+)').firstMatch(line);
        return match?.group(1);
      }
    }
    return null;
  }

  /// Spawn a zfa sub-process and capture output.
  Future<ProcessResult> _spawnZfa(List<String> args) async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      [if (_zfaBin.endsWith('.dart')) _zfaBin, ...args],
      workingDirectory: projectRoot,
    );
    return result;
  }
}
