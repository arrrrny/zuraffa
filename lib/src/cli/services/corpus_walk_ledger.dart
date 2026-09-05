/// `CorpusWalkLedger` — the ledger as merge gate (epic #1017
/// CORPUS-WALK, child "#1017 zfa corpus ledger --target=zik_zak —
/// ledger as merge gate").
///
/// The ledger records the walk's per-feature verdicts in the COMMITTED
/// file `corpus/ledgers/<target>.json` — committed to the repo, so it
/// persists across runs and PRs. The first ledger run writes the
/// baseline; every subsequent run is a DIFF against the committed
/// ledger:
///
/// - **regression** — a committed green contract that is now
///   partial/blocked, or a green feature that vanished from the walk.
///   Regressions are CI failures (exit 1): a new feature that breaks an
///   existing contract shows up exactly here — the previously-green
///   feature it broke.
/// - **renewed** — the spec hash changed but the feature stayed green
///   (the contract evolved and still holds; the hash renews).
/// - **added** — a feature new to the walk (recorded; NOT a regression —
///   the failure budget governs new gaps, not the ledger).
/// - **removed** — a feature that left the walk (a regression when it
///   was green — its contract vanished).
///
/// The ledger advances (is rewritten) only on a clean diff; a
/// contract-break leaves the committed ledger untouched so the break
/// cannot be absorbed by the very run that detected it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'corpus_catalog.dart';
import 'corpus_walker.dart';

/// One ledger row: the feature's verdict + contract hash.
class WalkLedgerFeature {
  const WalkLedgerFeature({
    required this.verdict,
    required this.specSha256,
    required this.classification,
    this.gate,
  });

  /// `green` / `partial` / `blocked` (WalkVerdict.name).
  final String verdict;
  final String specSha256;
  final String classification;
  final String? gate;

  Map<String, dynamic> toJson() => {
    'verdict': verdict,
    'spec_sha256': specSha256,
    'classification': classification,
    if (gate != null) 'gate': gate,
  };

  static WalkLedgerFeature fromJson(Map<String, dynamic> json) =>
      WalkLedgerFeature(
        verdict: json['verdict'] as String,
        specSha256: json['spec_sha256'] as String,
        classification: (json['classification'] as String?) ?? 'CORE',
        gate: json['gate'] as String?,
      );
}

/// The committed ledger for one target.
class WalkLedger {
  const WalkLedger({
    required this.target,
    required this.updatedAt,
    required this.features,
  });

  final String target;
  final String updatedAt;
  final Map<String, WalkLedgerFeature> features;

  Map<String, dynamic> toJson() => {
    'target': target,
    'updated_at': updatedAt,
    'features': {for (final e in features.entries) e.key: e.value.toJson()},
  };
}

/// Raised for ledger-level misfires (corrupt committed JSON). The
/// message names the recovery path with a `--> fix:` hint.
class WalkLedgerException implements Exception {
  const WalkLedgerException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The diff of a walk against the committed ledger.
class WalkLedgerDiff {
  const WalkLedgerDiff({
    required this.regressions,
    required this.added,
    required this.removed,
    required this.renewed,
  });

  /// `[ledger] <name>: green -> <verdict> (REGRESSION)` lines.
  final List<String> regressions;

  /// `[ledger] added: <name> (<verdict>)` lines.
  final List<String> added;

  /// `[ledger] removed: <name> (was <verdict>...)` lines.
  final List<String> removed;

  /// `[ledger] renewed: <name> (spec changed, still green)` lines.
  final List<String> renewed;

  bool get contractBreak => regressions.isNotEmpty;

  /// Computes the diff of [walk] (current) against [committed].
  static WalkLedgerDiff of(WalkResult walk, WalkLedger committed) {
    final regressions = <String>[];
    final added = <String>[];
    final removed = <String>[];
    final renewed = <String>[];

    final current = {for (final r in walk.results) r.name: r};

    for (final result in walk.results) {
      final row = committed.features[result.name];
      if (row == null) {
        added.add('[ledger] added: ${result.name} (${result.verdict.name})');
        continue;
      }
      final wasGreen = row.verdict == 'green';
      final isGreen = result.verdict == WalkVerdict.green;
      if (wasGreen && !isGreen) {
        regressions.add(
          '[ledger] ${result.name}: green -> ${result.verdict.name} '
          '(REGRESSION)',
        );
      } else if (isGreen && row.specSha256 != result.specSha256) {
        renewed.add(
          '[ledger] renewed: ${result.name} '
          '(spec changed, still green)',
        );
      }
    }

    for (final entry in committed.features.entries) {
      if (current.containsKey(entry.key)) continue;
      final wasGreen = entry.value.verdict == 'green';
      if (wasGreen) {
        regressions.add(
          '[ledger] removed: ${entry.key} (was green — REGRESSION: the '
          'contract vanished from the walk)',
        );
      } else {
        removed.add(
          '[ledger] removed: ${entry.key} (was ${entry.value.verdict})',
        );
      }
    }

    return WalkLedgerDiff(
      regressions: regressions,
      added: added,
      removed: removed,
      renewed: renewed,
    );
  }
}

/// Builds/reads the committed ledgers (`corpus/ledgers/`).
class WalkLedgerStore {
  const WalkLedgerStore(this.projectRoot);

  final String projectRoot;

  String get ledgersDirectory => p.join(projectRoot, 'corpus', 'ledgers');

  String ledgerPath(String target) => p.join(ledgersDirectory, '$target.json');

  /// Reads the committed ledger for [target]; `null` when none exists
  /// (the baseline case).
  ///
  /// Throws [WalkLedgerException] on a corrupt file, naming recovery.
  WalkLedger? read(String target) {
    final file = File(ledgerPath(target));
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) {
        throw const FormatException('top-level value is not an object');
      }
      final rows = decoded['features'];
      if (rows is! Map) {
        throw const FormatException('"features" is not an object');
      }
      return WalkLedger(
        target: decoded['target'] as String,
        updatedAt: (decoded['updated_at'] as String?) ?? '',
        features: {
          for (final entry in rows.entries)
            entry.key as String: WalkLedgerFeature.fromJson(
              (entry.value as Map).cast<String, dynamic>(),
            ),
        },
      );
    } on FormatException catch (e) {
      throw WalkLedgerException(
        'corrupted ledger for target "$target" (${ledgerPath(target)}): '
        '$e --> fix: repair it to valid ledger JSON, or regenerate the '
        'baseline by deleting the file and re-running '
        '`zfa corpus ledger --target $target` (the committed ledger is '
        'committed state — treat it like source).',
      );
    } on TypeError catch (e) {
      throw WalkLedgerException(
        'corrupted ledger for target "$target" (${ledgerPath(target)}): '
        '$e --> fix: regenerate the baseline (delete the file and re-run '
        '`zfa corpus ledger --target $target`).',
      );
    }
  }

  /// Writes the ledger deterministically (fixed key order, features
  /// sorted by name).
  Future<void> write(WalkLedger ledger) async {
    final file = File(ledgerPath(ledger.target));
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(ledger.toJson()));
  }
}

/// Materializes the committed ledger from a walk result (the rows the
/// next diff compares against).
WalkLedger ledgerFromWalk(WalkResult walk) {
  final rows = <String, WalkLedgerFeature>{};
  for (final result in walk.results) {
    rows[result.name] = WalkLedgerFeature(
      verdict: result.verdict.name,
      specSha256: result.specSha256,
      classification: result.classification == CorpusClass.core
          ? 'CORE'
          : 'SKIN',
      gate: result.gate,
    );
  }
  return WalkLedger(
    target: walk.target,
    updatedAt: DateTime.now().toUtc().toIso8601String(),
    features: rows,
  );
}
