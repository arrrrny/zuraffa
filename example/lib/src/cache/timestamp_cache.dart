// Auto-generated timestamp cache
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

Future<void> initTimestampCache() async {
  await Hive.openBox<int>('cache_timestamps');
}
