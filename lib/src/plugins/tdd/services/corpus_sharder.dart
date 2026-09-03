/// `CorpusSharder` — deterministic feature sharding for the corpus
/// lane (spec 069-corpus-economics, T003).
///
/// The per-PR corpus lane must complete ≤ 10 minutes (issue #916): the
/// manifest splits across N `zfa tdd corpus run --shard <i>/<n>`
/// invocations that run concurrently (a CI matrix of separate
/// checkouts), each driving its own subset. The distribution is
/// round-robin in manifest order:
///
/// - deterministic — the same manifest + shard spec always selects the
///   same features (plan risk: "sharding must produce deterministic
///   results"; no hashing, no environment input);
/// - exact coverage — every feature lands in exactly ONE shard; the
///   union of the shards equals the manifest (a feature is never
///   dropped and never double-driven);
/// - manifest order preserved WITHIN each shard (the drive order's
///   invariants — plan topological order included — hold per shard);
/// - balanced — shard sizes differ by at most one.
///
/// Shard specs are 1-based (`--shard 1/10` … `--shard 10/10`): a
/// malformed spec (`2`, `0/3`, `3/2`, `i/n`) is a usage error
/// ([ShardSpecFormatException]), never a silently-empty lane.
library;

/// A malformed `--shard <i>/<n>` spec.
class ShardSpecFormatException implements Exception {
  const ShardSpecFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CorpusSharder {
  const CorpusSharder._();

  /// Split [features] (manifest order) across [shardCount] round-robin
  /// shards: shard i carries the features at positions i, i+n, i+2n, …
  ///
  /// Returns exactly [shardCount] lists (a shard may be empty when
  /// shardCount exceeds the feature count — a feature is never
  /// dropped). `shardCount` must be >= 1.
  static List<List<String>> shard(List<String> features, int shardCount) {
    if (shardCount < 1) {
      throw ShardSpecFormatException(
        'shard count must be >= 1 (got $shardCount)',
      );
    }
    final shards = List.generate(shardCount, (_) => <String>[]);
    for (var i = 0; i < features.length; i++) {
      shards[i % shardCount].add(features[i]);
    }
    return shards;
  }

  /// The features of the 1-based shard [index] (1..[count]) of
  /// [ordered] — the `--shard <i>/<n>` selection.
  static List<String> selectShard({
    required List<String> ordered,
    required int index,
    required int count,
  }) {
    if (index < 1 || index > count) {
      throw ShardSpecFormatException(
        'shard index $index is out of range for a $count-shard split '
        '(expected 1..$count)',
      );
    }
    return shard(ordered, count)[index - 1];
  }

  /// Parse a `--shard <i>/<n>` spec (1-based i, n >= 1, i <= n).
  ///
  /// Throws [ShardSpecFormatException] on every malformed shape with a
  /// message naming the spec and the expected grammar.
  static (int, int) parseShardSpec(String spec) {
    final match = RegExp(r'^(\d+)/(\d+)$').firstMatch(spec.trim());
    if (match == null) {
      throw ShardSpecFormatException(
        'invalid --shard spec "$spec": expected the form <i>/<n> with '
        '1-based i (e.g. --shard 2/4 for the second of four shards).',
      );
    }
    final index = int.parse(match.group(1)!);
    final count = int.parse(match.group(2)!);
    if (count < 1) {
      throw ShardSpecFormatException(
        'invalid --shard spec "$spec": the shard count n must be >= 1.',
      );
    }
    if (index < 1 || index > count) {
      throw ShardSpecFormatException(
        'invalid --shard spec "$spec": the 1-based shard index must '
        'satisfy 1 <= i <= n for the <i>/<n> form (got i=$index, n=$count).',
      );
    }
    return (index, count);
  }
}
