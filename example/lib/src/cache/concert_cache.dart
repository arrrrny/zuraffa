import 'package:zuraffa/zuraffa.dart';

import '../domain/entities/concert/concert.dart';

/// Auto-generated cache for Concert
Future<void> initConcertCache() async {
  await Hive.openBox<Concert>('concerts');
}
