/// `CorpusWalker` — the corpus WALK (epic #1017 CORPUS-WALK, child
/// "#1016 zfa corpus run --target=zik_zak with configurable failure
/// budget").
///
/// The walk drives every cataloged feature through the loop runtime's
/// per-feature machine contract — the same `zfa tdd run` / `zfa tdd
/// verify` sub-process spawns `zfa tdd corpus run` (spec 051) uses — and
/// classifies each feature:
///
/// - **green** — the run completes AND the verify gate passes.
/// - **partial** — the run completes but the verify gate is non-pass
///   (some behaviors proven, some not: `fail_survived`, …).
/// - **blocked** — the feature cannot be driven: not-ready (never
///   spawned), a failed run step, or a runner misfire.
///
/// Unlike STOP-ON-ROADBLOCK (spec 051 FR-002), the walk NEVER stops at a
/// failing feature: it walks the whole corpus and reports the tallies,
/// because the configurable failure budget (partial + blocked <= budget)
/// is the gate — not the first failure. The walk's results persist to
/// `.zfa/corpus/walks/<target>.json` (runtime state; the ledger is the
/// committed record).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../plugins/tdd/services/corpus_step_runner.dart';
import 'corpus_catalog.dart';

/// One walked feature's verdict.
enum WalkVerdict { green, partial, blocked }

/// One feature's walk result.
class WalkFeatureResult {
  const WalkFeatureResult({
    required this.name,
    required this.verdict,
    required this.specSha256,
    required this.classification,
    this.gate,
    this.outcome,
    this.detail,
  });

  final String name;
  final WalkVerdict verdict;
  final String specSha256;
  final CorpusClass classification;

  /// The verify gate label (`pass`, `fail_survived`, …) when spawned.
  final String? gate;

  /// The run outcome token (`complete`, `stopped`, …) when spawned.
  final String? outcome;

  /// The blocked detail (not-ready reason or failing outcome).
  final String? detail;

  Map<String, dynamic> toJson() => {
    'verdict': verdict.name,
    'spec_sha256': specSha256,
    'classification': classification == CorpusClass.core ? 'CORE' : 'SKIN',
    if (gate != null) 'gate': gate,
    if (outcome != null) 'outcome': outcome,
    if (detail != null) 'detail': detail,
  };

  String get reportLine {
    switch (verdict) {
      case WalkVerdict.green:
        return '[corpus-walk] $name -> green (gate=${gate ?? 'pass'})';
      case WalkVerdict.partial:
        return '[corpus-walk] $name -> partial (gate=${gate ?? 'unknown'})';
      case WalkVerdict.blocked:
        return '[corpus-walk] $name -> blocked (${detail ?? 'unknown'})';
    }
  }
}

/// The whole walk: per-feature results in catalog order + tallies.
class WalkResult {
  const WalkResult({
    required this.target,
    required this.at,
    required this.results,
  });

  final String target;
  final String at;
  final List<WalkFeatureResult> results;

  int get green => results.where((r) => r.verdict == WalkVerdict.green).length;
  int get partial =>
      results.where((r) => r.verdict == WalkVerdict.partial).length;
  int get blocked =>
      results.where((r) => r.verdict == WalkVerdict.blocked).length;
  int get used => partial + blocked;

  Map<String, dynamic> toJson() => {
    'target': target,
    'at': at,
    'features': {for (final r in results) r.name: r.toJson()},
    'summary': {'green': green, 'partial': partial, 'blocked': blocked},
  };
}

/// Raised when the walk cannot start (no catalog, empty catalog, bad
/// budget). The message names the recovery path with a `--> fix:` hint.
class CorpusWalkException implements Exception {
  const CorpusWalkException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Parses the `--budget` flag (the configurable failure budget; epic
/// exit criterion M+K <= 5, so the default is 5). Non-negative integer.
int parseFailureBudget(String? raw) {
  if (raw == null || raw.isEmpty) return 5;
  final value = int.tryParse(raw);
  if (value == null || value < 0) {
    throw CorpusWalkException(
      'invalid failure budget "$raw" — the budget is the maximum number '
      'of non-green features (partial + blocked) the walk tolerates; '
      'pass a non-negative integer (default 5).',
    );
  }
  return value;
}

/// Reads the committed catalog for [target] or throws the guidance
/// misfire (the walk's input contract is the catalog, never the raw
/// manifest — classification is part of the walk record).
CorpusCatalog requireCatalog({
  required String target,
  required String projectRoot,
}) {
  validateTargetName(target);
  final catalog = CorpusCatalogStore(projectRoot).read(target);
  if (catalog == null) {
    throw CorpusWalkException(
      'no catalog for target "$target" '
      '(${p.join(projectRoot, 'corpus', 'catalogs', '$target.json')}) — '
      'the walk drives the cataloged features. --> fix: run '
      '`zfa corpus catalog --target $target` first.',
    );
  }
  if (catalog.features.isEmpty) {
    throw CorpusWalkException(
      'the catalog for target "$target" holds no features — a walk of '
      'nothing is a misfire, never a silent success. --> fix: re-run '
      '`zfa corpus catalog --target $target` against a non-empty corpus.',
    );
  }
  return catalog;
}

/// The walker: drives every cataloged feature and classifies the
/// verdicts (never stopping at a failure — the budget is the gate).
class CorpusWalker {
  CorpusWalker({this.zfaBin, Duration? timeout})
    : _runner = CorpusStepRunner(zfaBin: zfaBin, timeout: timeout);

  final String? zfaBin;
  final CorpusStepRunner _runner;

  /// Walks [catalog] in catalog order, printing each feature's verdict
  /// line through [printLine].
  Future<WalkResult> walk(
    CorpusCatalog catalog, {
    required String projectRoot,
    void Function(String line)? printLine,
  }) async {
    final emit = printLine ?? print;
    final results = <WalkFeatureResult>[];
    for (final feature in catalog.features) {
      // The contract hash is taken at WALK TIME (specs/<f>/spec.md as it
      // is now), never from the catalog's recorded hash — a spec that
      // drifted since cataloging shows up in the ledger diff (renewal
      // when still green, drift evidence when not). A spec missing at
      // walk time is a blocked misfire, never a silent skip.
      final specFile = File(
        p.join(projectRoot, 'specs', feature.name, 'spec.md'),
      );
      final String specSha256;
      if (specFile.existsSync()) {
        specSha256 = sha256.convert(specFile.readAsBytesSync()).toString();
      } else {
        specSha256 = feature.specSha256;
      }
      final specMissing = !specFile.existsSync();

      // Not-ready: blocked without being spawned (the 051 FR-003 rule,
      // one level up — reported, never driven).
      if (!feature.ready || specMissing) {
        final reason = specMissing
            ? 'spec missing (specs/${feature.name}/spec.md)'
            : feature.reason.isEmpty
            ? 'not-ready (no reason recorded)'
            : 'not-ready: ${feature.reason}';
        final result = WalkFeatureResult(
          name: feature.name,
          verdict: WalkVerdict.blocked,
          specSha256: specSha256,
          classification: feature.classification,
          detail: reason,
        );
        results.add(result);
        emit(result.reportLine);
        continue;
      }

      // --- zfa tdd run <feature> ---
      final runResult = await _runner.runFeature(
        feature: feature.name,
        projectRoot: projectRoot,
      );
      if (!runResult.success) {
        final result = WalkFeatureResult(
          name: feature.name,
          verdict: WalkVerdict.blocked,
          specSha256: specSha256,
          classification: feature.classification,
          outcome: runResult.outcome,
          detail: runResult.outcome,
        );
        results.add(result);
        emit(result.reportLine);
        continue;
      }

      // --- zfa tdd verify --feature <feature> ---
      final verifyResult = await _runner.verifyFeature(
        feature: feature.name,
        projectRoot: projectRoot,
      );
      final result = WalkFeatureResult(
        name: feature.name,
        verdict: verifyResult.success ? WalkVerdict.green : WalkVerdict.partial,
        specSha256: specSha256,
        classification: feature.classification,
        gate: verifyResult.outcome,
        outcome: runResult.outcome,
      );
      results.add(result);
      emit(result.reportLine);
    }

    return WalkResult(
      target: catalog.target,
      at: DateTime.now().toUtc().toIso8601String(),
      results: results,
    );
  }
}

/// Persists the walk results (runtime state under `.zfa/corpus/`).
Future<void> persistWalkResult(String projectRoot, WalkResult walk) async {
  final file = File(
    p.join(projectRoot, '.zfa', 'corpus', 'walks', '${walk.target}.json'),
  );
  await file.parent.create(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString(encoder.convert(walk.toJson()));
}

/// sha256 hex of a spec file's bytes — the walk record's currency.
String specSha256OfFile(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();
