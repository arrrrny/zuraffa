// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../domain/entities/enums/index.dart';
import '../domain/entities/todo/todo.dart';

part 'hive_registrar.g.dart';

@GenerateAdapters([AdapterSpec<Todo>()])
extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(TodoAdapter());
  }
}

extension IsolatedHiveRegistrar on IsolatedHiveInterface {
  void registerAdapters() {
    registerAdapter(TodoAdapter());
  }
}

// END GENERATED
