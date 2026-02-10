import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../data/data_sources/todo/todo_local_data_source.dart';
import '../../domain/entities/todo/todo.dart';

void registerTodoLocalDataSource(GetIt getIt) {
  getIt.registerLazySingleton<TodoLocalDataSource>(
    () => TodoLocalDataSource(Hive.box<Todo>('todos')),
  );
}
