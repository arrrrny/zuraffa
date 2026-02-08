// Auto-generated - DO NOT EDIT
export 'timestamp_cache.dart';
export 'hive_registrar.dart';
export 'todo_cache.dart';
export 'product_cache.dart';
export 'daily_cache_policy.dart';
export 'ttl_5_minutes_cache_policy.dart';

import 'timestamp_cache.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'hive_registrar.dart';
import 'todo_cache.dart';
import 'product_cache.dart';

Future<void> initAllCaches() async {
  Hive.registerAdapters();
  await initTimestampCache();
  await initTodoCache();
  await initProductCache();
}
