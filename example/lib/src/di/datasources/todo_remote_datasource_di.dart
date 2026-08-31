// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/todo/todo_remote_datasource.dart';

void registerTodoRemoteDataSource(GetIt getIt) {
  getIt.registerLazySingleton<TodoRemoteDataSource>(
    () => TodoRemoteDataSource(),
  );
}

// END GENERATED
