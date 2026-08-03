import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../domain/entities/todo.dart';

part 'hive_setup.g.dart';

/// Registers Hive type adapters for zorphy-generated entities.
///
/// Zorphy entities are immutable value classes — they don't implement
/// Hive's [HiveObject] interface. The [AdapterSpec] annotation tells
/// hive_ce_generator to create a [TypeAdapter] for [Todo].
@GenerateAdapters([
  AdapterSpec<Todo>(),
])
extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(TodoAdapter());
  }
}

/// Isolated version for non-Flutter isolate contexts.
extension IsolatedHiveRegistrar on IsolatedHiveInterface {
  void registerAdapters() {
    registerAdapter(TodoAdapter());
  }
}
