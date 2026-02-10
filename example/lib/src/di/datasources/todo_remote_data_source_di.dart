import 'package:get_it/get_it.dart';

import '../../data/data_sources/todo/todo_remote_data_source.dart';

void registerTodoRemoteDataSource(GetIt getIt) {
  getIt.registerLazySingleton<TodoRemoteDataSource>(
    () => TodoRemoteDataSource(),
  );
}
