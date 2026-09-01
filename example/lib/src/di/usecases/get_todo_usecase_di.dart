// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/todo_repository.dart';
import '../../domain/usecases/todo/get_todo_usecase.dart';

void registerGetTodoUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetTodoUseCase>(
    () => GetTodoUseCase(getIt<TodoRepository>()),
  );
}

// END GENERATED
