import 'package:zuraffa/zuraffa.dart';

/// Auto-generated cache policy
CachePolicy createTtl5MinutesCachePolicy() {
  final timestampBox = Hive.box<int>('cache_timestamps');
  if (Zuraffa.disableCache) {
    return DisabledCachePolicy();
  }
  return TtlCachePolicy(
    ttl: const Duration(minutes: 5),
    getTimestamps: () async => Map<String, int>.from(timestampBox.toMap()),
    setTimestamp: (key, timestamp) async =>
        await timestampBox.put(key, timestamp),
    removeTimestamp: (key) async => await timestampBox.delete(key),
    clearAll: () async => await timestampBox.clear(),
  );
}
