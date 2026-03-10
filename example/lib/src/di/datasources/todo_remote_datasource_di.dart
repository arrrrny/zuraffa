import 'package:get_it/get_it.dart';

import '../../data/datasources/todo/todo_remote_datasource.dart';

void registerTodoRemoteDataSource(GetIt getIt) {
  getIt.registerLazySingleton<TodoRemoteDataSource>(
    () => TodoRemoteDataSource(),
  );
}
