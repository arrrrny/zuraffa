import 'package:get_it/get_it.dart';

import '../../data/datasources/todo/todo_mock_datasource.dart';

void registerTodoMockDataSource(GetIt getIt) {
  getIt.registerLazySingleton<TodoMockDataSource>(() => TodoMockDataSource());
}
