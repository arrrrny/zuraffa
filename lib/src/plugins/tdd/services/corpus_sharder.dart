/// `CorpusSharder` — deterministic feature sharding for the corpus lane
/// (spec 069-corpus-economics, issue #916: the per-PR corpus lane
/// ≤ 10 minutes via sharding).
///
/// The 120-feature corpus splits across `k` parallel CI jobs
/// (`zfa tdd corpus run --shard <i>/<k>`); each job drives only its own
/// shard, so wall-clock divides by the lane count while every feature
/// is still driven exactly once across the matrix.
///
/// Determinism contract (the plan's risk list: "sharding must produce
/// deterministic results"):
/// - The assignment is ROUND-ROBIN over the GIVEN order: shard `i` of
///   `k` receives features at indices `i, i+k, i+2k, ...`. Given the
///   same feature list, every machine and every re-run computes the
///   exact same shards — no hashing, no randomization, no wall-clock.
/// - The input order is the corpus's own drive order (manifest or
///   topological) — the sharder never re-sorts it, preserving the
///   dependency-ordered semantics of bug #836's `--plan`.
/// - Shards are CONTIGUOUS-FREE (interleaved): a slow feature lands in
///   exactly one shard; the union of all shards is the full list, and
///   the pairwise intersection is empty.
library;

import 'dart:math' as math;

class CorpusSharder {
  const CorpusSharder();

  /// Shard [features] into [shardCount] shards, round-robin over the
  /// given order. `shardCount` must be >= 1; a count larger than the
  /// feature count yields trailing empty shards (a CI matrix with more
  /// lanes than features just no-ops the extra lanes).
  List<List<String>> shard({
    required List<String> features,
    required int shardCount,
  }) {
    if (shardCount < 1) {
      throw ArgumentError.value(
        shardCount,
        'shardCount',
        'the shard count must be at least 1',
      );
    }
    final shards = List.generate(shardCount, (_) => <String>[]);
    for (var i = 0; i < features.length; i++) {
      shards[i % shardCount].add(features[i]);
    }
    return shards;
  }

  /// The features assigned to shard [shardIndex] of [shardCount] —
  /// the lane `zfa tdd corpus run --shard <shardIndex+1>/<shardCount>`
  /// drives (1-BASED on the CLI to match CI matrix notation).
  List<String> shardLane({
    required List<String> features,
    required int shardCount,
    required int shardIndex,
  }) {
    if (shardIndex < 0 || shardIndex >= shardCount) {
      throw ArgumentError.value(
        shardIndex,
        'shardIndex',
        'must be in [0, $shardCount) (0-based; the CLI flag is 1-based)',
      );
    }
    return shard(features: features, shardCount: shardCount)[shardIndex];
  }

  /// Parse a `--shard <i>/<k>` CLI value into (i, k) with 1-based i.
  /// Returns null when [raw] is null/empty; throws [FormatException]
  /// on malformed values (never silently falls back to a wrong lane —
  /// a mistyped shard spec drives the WRONG features).
  static (int, int)? parseShardSpec(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'^\s*(\d+)\s*/\s*(\d+)\s*$').firstMatch(raw);
    if (match == null) {
      throw FormatException(
        'invalid --shard "$raw": expected the CI matrix form <i>/<k> '
        'such as 1/4 (1-based lane index of the lane count).',
      );
    }
    final index = int.parse(match.group(1)!);
    final count = int.parse(match.group(2)!);
    if (count < 1) {
      throw FormatException(
        'invalid --shard "$raw": the lane count must be at least 1.',
      );
    }
    if (index < 1 || index > count) {
      throw FormatException(
        'invalid --shard "$raw": the lane index must be in [1, $count].',
      );
    }
    return (index, count);
  }

  /// A suggested lane count for [featureCount] features and a
  /// [targetLaneMinutes] wall-clock budget: the smallest lane count
  /// whose even share of the features fits the budget at
  /// [minutesPerFeature] per feature. Never suggests more lanes than
  /// features (an empty lane is a wasted CI job) and never fewer than 1.
  static int suggestLaneCount({
    required int featureCount,
    required double minutesPerFeature,
    required double targetLaneMinutes,
  }) {
    if (featureCount <= 0) return 1;
    if (minutesPerFeature <= 0) return 1;
    final needed = (featureCount * minutesPerFeature) / targetLaneMinutes;
    return math.min(featureCount, math.max(1, needed.ceil()));
  }
}
