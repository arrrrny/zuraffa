import 'package:zuraffa/zuraffa.dart';

/// Auto-generated timestamp cache
Future<void> initTimestampCache() async {
  await Hive.openBox<int>('cache_timestamps');
}
