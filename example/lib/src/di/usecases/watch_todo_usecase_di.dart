// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/todo_repository.dart';
import '../../domain/usecases/todo/watch_todo_usecase.dart';

void registerWatchTodoUseCase(GetIt getIt) {
  getIt.registerLazySingleton<WatchTodoUseCase>(
    () => WatchTodoUseCase(getIt<TodoRepository>()),
  );
}

// END GENERATED
