// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/todo_repository.dart';
import '../../domain/usecases/todo/create_todo_usecase.dart';

void registerCreateTodoUseCase(GetIt getIt) {
  getIt.registerLazySingleton<CreateTodoUseCase>(
    () => CreateTodoUseCase(getIt<TodoRepository>()),
  );
}

// END GENERATED
