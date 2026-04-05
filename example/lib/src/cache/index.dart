import 'package:zuraffa/zuraffa.dart';

import 'concert_cache.dart';
import 'hive_registrar.dart';
import 'product_cache.dart';
import 'timestamp_cache.dart';
import 'todo_cache.dart';

export 'concert_cache.dart';
export 'daily_cache_policy.dart';
export 'hive_registrar.dart';
export 'product_cache.dart';
export 'timestamp_cache.dart';
export 'todo_cache.dart';
export 'ttl_5_minutes_cache_policy.dart';

/// Auto-generated - DO NOT EDIT
Future<void> initAllCaches() async {
  Hive.registerAdapters();
  await initTimestampCache();
  await initConcertCache();
  await initTodoCache();
  await initProductCache();
}
