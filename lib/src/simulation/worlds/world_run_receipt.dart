/// World run receipts (spec 968; issue #807 composes): every green run
/// is attributable to a world version.
///
/// `zfa simulate run` writes a proof-carrying receipt at
/// `.zfa/receipts/world-run-<scenario>.json` via the shared
/// [ReceiptStore.saveNamed] contract (issue #996): a parseable
/// `proof.v1` [GenerationReceipt] plus the world extras (scenario,
/// world hash, seed, verdict, plays, run digest, virtual elapsed)
/// merged on top — `zfa proof check` keeps seeing a valid receipt
/// while the world machinery reads the world fields.
///
/// Receipt discipline (the #1001 rule, restated): a stale green
/// receipt never survives. When `simulate run` detects the world
/// mutated since the recorded green (world hash mismatch), the run
/// refuses BEFORE executing and the receipt on disk is rewritten as an
/// invalidation record (`world_valid: false`, verdict RED, the drift
/// named) — the mutation is what invalidates the receipt, exactly as
/// issue #968's acceptance criterion 2 requires.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/project/receipt_store.dart';

/// The world-run receipt envelope (proof.v1 + world extras).
final class WorldRunReceipt {
  const WorldRunReceipt({
    required this.scenario,
    required this.feature,
    required this.worldHash,
    required this.seed,
    required this.verdict,
    required this.passed,
    required this.worldValid,
    required this.plays,
    required this.runDigest,
    required this.virtualElapsedMs,
    required this.at,
    required this.path,
    this.invalidatedBy,
  });

  final String scenario;
  final String feature;

  /// The world hash this run executed against (GREEN is attributable to
  /// exactly this world version).
  final String worldHash;

  final int seed;

  /// `GREEN` / `RED`.
  final String verdict;

  /// Whether the recorded run passed.
  final bool passed;

  /// Whether the receipt is still a valid proof (`false` = the world
  /// mutated and the receipt was invalidated).
  final bool worldValid;

  /// Number of recorded plays.
  final int plays;

  /// The deterministic run digest (replay compares this).
  final String runDigest;

  final int virtualElapsedMs;

  /// ISO-8601 UTC of the recorded run.
  final String at;

  /// The receipt file's path.
  final String path;

  /// Why a receipt was invalidated (`world-mutation`).
  final String? invalidatedBy;

  Map<String, dynamic> toExtra() => {
    'scenario': scenario,
    'feature': feature,
    'world_hash': worldHash,
    'seed': seed,
    'verdict': verdict,
    'world_valid': worldValid,
    'plays': plays,
    'run_digest': runDigest,
    'virtual_elapsed_ms': virtualElapsedMs,
    if (invalidatedBy != null) 'invalidated_by': invalidatedBy,
  };
}

/// Reads and writes world-run receipts through the [ReceiptStore].
final class WorldRunReceiptStore {
  WorldRunReceiptStore({required this.projectRoot});

  final String projectRoot;

  ReceiptStore get _store => ReceiptStore(projectRoot: projectRoot);

  /// The deterministic receipt name for [scenario] (latest-wins per the
  /// `saveNamed` contract). Sanitized with the ReceiptStore's rules so
  /// the name the command predicts always matches the name on disk.
  String fileNameFor(String scenario) =>
      'world-run-${_sanitize(scenario)}.json';

  static String _sanitize(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');

  /// Persist a run receipt. [GenerationReceipt.at] must carry the run's
  /// timestamp; the world extras merge on top of the proof.v1 payload.
  Future<File> save(WorldRunReceipt receipt) => _store.saveNamed(
    fileNameFor(receipt.scenario),
    GenerationReceipt(
      command: 'simulate run ${receipt.scenario}',
      target: receipt.scenario,
      repro:
          'zfa simulate run ${receipt.scenario}'
          '${receipt.feature.isEmpty ? '' : ' --feature ${receipt.feature}'}'
          ' --seed ${receipt.seed}',
      at: DateTime.parse(receipt.at),
      generatorVersion: 'zuraffa-worlds-1',
      input: {
        'scenario': receipt.scenario,
        'feature': receipt.feature,
        'seed': receipt.seed,
      },
      files: const [],
      plugin: 'simulate',
      capability: 'run',
      entity: receipt.scenario,
    ),
    extra: receipt.toExtra(),
  );

  /// Load the current run receipt for [scenario], or `null` when no
  /// receipt exists (never run).
  WorldRunReceipt? load(String scenario) {
    final file = File(
      p.join(projectRoot, '.zfa', 'receipts', fileNameFor(scenario)),
    );
    if (!file.existsSync()) return null;
    try {
      final doc = jsonDecode(file.readAsStringSync());
      if (doc is! Map<String, dynamic>) return null;
      return WorldRunReceipt(
        scenario: doc['scenario'] as String? ?? scenario,
        feature: doc['feature'] as String? ?? '',
        worldHash: doc['world_hash'] as String? ?? '',
        seed: (doc['seed'] as num?)?.toInt() ?? 0,
        verdict: doc['verdict'] as String? ?? '',
        passed: doc['verdict'] == 'GREEN',
        worldValid: doc['world_valid'] as bool? ?? false,
        plays: (doc['plays'] as num?)?.toInt() ?? 0,
        runDigest: doc['run_digest'] as String? ?? '',
        virtualElapsedMs: (doc['virtual_elapsed_ms'] as num?)?.toInt() ?? 0,
        at: doc['at'] as String? ?? '',
        path: file.path,
        invalidatedBy: doc['invalidated_by'] as String?,
      );
    } on FormatException {
      return null;
    }
  }
}
