import 'package:zuraffa/zuraffa.dart';

/// Auto-generated cache policy
CachePolicy createDailyCachePolicy() {
  final timestampBox = Hive.box<int>('cache_timestamps');
  if (Zuraffa.disableCache) {
    return DisabledCachePolicy();
  }
  return DailyCachePolicy(
    getTimestamps: () async => Map<String, int>.from(timestampBox.toMap()),
    setTimestamp: (key, timestamp) async =>
        await timestampBox.put(key, timestamp),
    removeTimestamp: (key) async => await timestampBox.delete(key),
    clearAll: () async => await timestampBox.clear(),
  );
}
