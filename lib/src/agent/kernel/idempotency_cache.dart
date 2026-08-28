import 'dart:collection';

import 'mission.dart';

/// A TTL-bounded idempotency cache (FR-007).
///
/// Re-submitting a completed mission key within the configured TTL returns
/// the cached outcome wrapped in [OutcomeCachedServed]. After TTL expiry,
/// the entry is evicted and the next submission executes fresh.
///
/// The cache is bounded by [maxEntries]; the oldest entry (by insertion
/// order) is evicted when full.
class IdempotencyCache {
  IdempotencyCache({
    this.ttl = const Duration(minutes: 5),
    this.maxEntries = 256,
    this.enabled = true,
  });

  /// TTL for cached outcomes. Zero disables the cache (every submission
  /// runs fresh).
  Duration ttl;

  /// Maximum entries before LRU eviction.
  final int maxEntries;

  /// Whether idempotency is enabled. When false, [lookup] always returns
  /// null.
  bool enabled;

  final LinkedHashMap<MissionKey, _Cached> _entries =
      LinkedHashMap<MissionKey, _Cached>();

  /// Looks up a cached outcome. Returns null if not present, expired,
  /// or disabled. Evicts expired entries on read.
  MissionOutcome? lookup(MissionKey key) {
    if (!enabled || ttl == Duration.zero) return null;
    final now = DateTime.now();
    final cached = _entries[key];
    if (cached == null) return null;
    if (now.isAfter(cached.expiresAt)) {
      _entries.remove(key);
      return null;
    }
    // Refresh insertion order for LRU.
    _entries.remove(key);
    _entries[key] = cached;
    return OutcomeCachedServed(cached.outcome);
  }

  /// Stores [outcome] for [key] with TTL starting at [now].
  void store(MissionKey key, MissionOutcome outcome) {
    if (!enabled || ttl == Duration.zero) return;
    final now = DateTime.now();
    final expiresAt = now.add(ttl);
    if (_entries.length >= maxEntries && !_entries.containsKey(key)) {
      _entries.remove(_entries.keys.first);
    }
    _entries[key] = _Cached(outcome, expiresAt);
  }

  /// Number of live entries (excluding expired).
  int get size {
    _evictExpired();
    return _entries.length;
  }

  /// Clears all entries.
  void clear() => _entries.clear();

  void _evictExpired() {
    final now = DateTime.now();
    _entries.removeWhere((_, c) => now.isAfter(c.expiresAt));
  }
}

class _Cached {
  _Cached(this.outcome, this.expiresAt);
  final MissionOutcome outcome;
  final DateTime expiresAt;
}
