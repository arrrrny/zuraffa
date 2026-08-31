// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/todo_repository.dart';
import '../../domain/usecases/todo/delete_todo_usecase.dart';

void registerDeleteTodoUseCase(GetIt getIt) {
  getIt.registerLazySingleton<DeleteTodoUseCase>(
    () => DeleteTodoUseCase(getIt<TodoRepository>()),
  );
}

// END GENERATED
