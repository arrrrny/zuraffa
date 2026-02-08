// Auto-generated DI registration for TodoRepository
import 'package:example/src/data/data_sources/todo/todo_mock_data_source.dart';
import 'package:get_it/get_it.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../data/repositories/data_todo_repository.dart';
import '../../data/data_sources/todo/todo_local_data_source.dart';
import '../../cache/daily_cache_policy.dart';

void registerTodoRepository(GetIt getIt) {
  getIt.registerLazySingleton<TodoRepository>(
    () => DataTodoRepository(
      getIt<TodoMockDataSource>(),
      getIt<TodoLocalDataSource>(),
      createDailyCachePolicy(),
    ),
  );
}
