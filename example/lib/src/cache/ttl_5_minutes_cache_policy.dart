// Auto-generated cache policy
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:zuraffa/zuraffa.dart';

CachePolicy createTtl5MinutesCachePolicy() {
  final timestampBox = Hive.box<int>('cache_timestamps');
  return TtlCachePolicy(
    ttl: const Duration(minutes: 5),
    getTimestamps: () async => Map<String, int>.from(timestampBox.toMap()),
    setTimestamp: (key, timestamp) async =>
        await timestampBox.put(key, timestamp),
    removeTimestamp: (key) async => await timestampBox.delete(key),
    clearAll: () async => await timestampBox.clear(),
  );
}
