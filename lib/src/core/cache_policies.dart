import 'cache_policy.dart';

/// Daily cache expiration policy.
///
/// Caches are considered valid for 24 hours from when they were marked fresh.
///
/// ## Example
/// ```dart
/// final policy = DailyCachePolicy(sharedPreferences);
/// if (await policy.isValid('products')) {
///   // Use cached data
/// } else {
///   // Fetch fresh data
///   await policy.markFresh('products');
/// }
/// ```
class DailyCachePolicy implements CachePolicy {
  final Future<Map<String, int>> Function() _getTimestamps;
  final Future<void> Function(String key, int timestamp) _setTimestamp;
  final Future<void> Function(String key) _removeTimestamp;
  final Future<void> Function() _clearAll;

  DailyCachePolicy({
    required Future<Map<String, int>> Function() getTimestamps,
    required Future<void> Function(String key, int timestamp) setTimestamp,
    required Future<void> Function(String key) removeTimestamp,
    required Future<void> Function() clearAll,
  }) : _getTimestamps = getTimestamps,
       _setTimestamp = setTimestamp,
       _removeTimestamp = removeTimestamp,
       _clearAll = clearAll;

  @override
  Future<bool> isValid(String key) async {
    final timestamps = await _getTimestamps();
    final timestamp = timestamps['cache_$key'];
    if (timestamp == null) return false;

    final cached = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    return now.difference(cached).inDays < 1;
  }

  @override
  Future<void> markFresh(String key) async {
    await _setTimestamp('cache_$key', DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Future<void> invalidate(String key) async {
    await _removeTimestamp('cache_$key');
  }

  @override
  Future<void> clear() async {
    await _clearAll();
  }
}

/// App restart cache policy.
///
/// Caches are valid only for the current app session.
/// All caches are invalidated when the app restarts.
///
/// ## Example
/// ```dart
/// final policy = AppRestartCachePolicy();
/// if (await policy.isValid('configs')) {
///   // Use cached data
/// } else {
///   // Fetch fresh data
///   await policy.markFresh('configs');
/// }
/// ```
class AppRestartCachePolicy implements CachePolicy {
  final Map<String, bool> _inMemoryCache = {};

  @override
  Future<bool> isValid(String key) async {
    return _inMemoryCache[key] ?? false;
  }

  @override
  Future<void> markFresh(String key) async {
    _inMemoryCache[key] = true;
  }

  @override
  Future<void> invalidate(String key) async {
    _inMemoryCache.remove(key);
  }

  @override
  Future<void> clear() async {
    _inMemoryCache.clear();
  }
}

/// Time-to-live (TTL) cache policy.
///
/// Caches expire after a specified duration.
///
/// ## Example
/// ```dart
/// final policy = TtlCachePolicy(
///   ttl: const Duration(hours: 6),
///   getTimestamps: () async => prefs.getInt('cache_timestamp'),
///   setTimestamp: (key, ts) async => prefs.setInt(key, ts),
///   removeTimestamp: (key) async => prefs.remove(key),
///   clearAll: () async => prefs.clear(),
/// );
/// ```
class TtlCachePolicy implements CachePolicy {
  final Duration ttl;
  final Future<Map<String, int>> Function() _getTimestamps;
  final Future<void> Function(String key, int timestamp) _setTimestamp;
  final Future<void> Function(String key) _removeTimestamp;
  final Future<void> Function() _clearAll;

  TtlCachePolicy({
    required this.ttl,
    required Future<Map<String, int>> Function() getTimestamps,
    required Future<void> Function(String key, int timestamp) setTimestamp,
    required Future<void> Function(String key) removeTimestamp,
    required Future<void> Function() clearAll,
  }) : _getTimestamps = getTimestamps,
       _setTimestamp = setTimestamp,
       _removeTimestamp = removeTimestamp,
       _clearAll = clearAll;

  @override
  Future<bool> isValid(String key) async {
    final timestamps = await _getTimestamps();
    final timestamp = timestamps['cache_$key'];
    if (timestamp == null) return false;

    final cached = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    return now.difference(cached) < ttl;
  }

  @override
  Future<void> markFresh(String key) async {
    await _setTimestamp('cache_$key', DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Future<void> invalidate(String key) async {
    await _removeTimestamp('cache_$key');
  }

  @override
  Future<void> clear() async {
    await _clearAll();
  }
}
