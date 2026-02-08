// Auto-generated DI registration for TodoRemoteDataSource
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../data/data_sources/todo/todo_remote_data_source.dart';
import '../../domain/entities/todo/todo.dart';

void registerTodoRemoteDataSource(GetIt getIt) {
  getIt.registerLazySingleton<TodoRemoteDataSource>(
    () {
      // Load cached todos to seed the remote data source
      final box = Hive.box<Todo>('todos');
      final cachedTodos = box.values.toList();

      return TodoRemoteDataSource(initialTodos: cachedTodos);
    },
  );
}
