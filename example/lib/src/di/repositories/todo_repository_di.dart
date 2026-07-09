import 'package:get_it/get_it.dart';

import '../../cache/daily_cache_policy.dart';
import '../../data/datasources/todo/todo_local_datasource.dart';
import '../../data/repositories/data_todo_repository.dart';
import '../../domain/repositories/todo_repository.dart';

/// PROTOTYPE: uses the local Hive data source as both remote and local so
/// the unimplemented remote API does not block VM service extension demos.
/// Revert to TodoRemoteDataSource once the remote API is implemented.
void registerTodoRepository(GetIt getIt) {
  getIt.registerLazySingleton<TodoRepository>(
    () => DataTodoRepository(
      getIt<TodoLocalDataSource>(),
      getIt<TodoLocalDataSource>(),
      createDailyCachePolicy(),
    ),
  );
}
