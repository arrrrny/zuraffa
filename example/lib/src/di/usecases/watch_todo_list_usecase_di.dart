// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/todo_repository.dart';
import '../../domain/usecases/todo/watch_todo_list_usecase.dart';

void registerWatchTodoListUseCase(GetIt getIt) {
  getIt.registerLazySingleton<WatchTodoListUseCase>(
    () => WatchTodoListUseCase(getIt<TodoRepository>()),
  );
}

// END GENERATED
