import 'package:get_it/get_it.dart';

import '../../cache/daily_cache_policy.dart';
import '../../data/datasources/todo/todo_local_datasource.dart';
import '../../data/datasources/todo/todo_remote_datasource.dart';
import '../../data/repositories/data_todo_repository.dart';
import '../../domain/repositories/todo_repository.dart';

void registerTodoRepository(GetIt getIt) {
  getIt.registerLazySingleton<TodoRepository>(
    () => DataTodoRepository(
      getIt<TodoRemoteDataSource>(),
      getIt<TodoLocalDataSource>(),
      createDailyCachePolicy(),
    ),
  );
}
