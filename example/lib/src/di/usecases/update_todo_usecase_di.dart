// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/todo_repository.dart';
import '../../domain/usecases/todo/update_todo_usecase.dart';

void registerUpdateTodoUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateTodoUseCase>(
    () => UpdateTodoUseCase(getIt<TodoRepository>()),
  );
}

// END GENERATED
