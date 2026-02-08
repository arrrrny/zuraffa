// Auto-generated DI registration for TodoMockDataSource
import 'package:get_it/get_it.dart';
import '../../data/data_sources/todo/todo_mock_data_source.dart';

void registerTodoMockDataSource(GetIt getIt) {
  getIt.registerLazySingleton<TodoMockDataSource>(
    () => TodoMockDataSource(),
  );
}
