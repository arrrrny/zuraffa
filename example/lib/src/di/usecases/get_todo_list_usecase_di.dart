// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/todo_repository.dart';
import '../../domain/usecases/todo/get_todo_list_usecase.dart';

void registerGetTodoListUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetTodoListUseCase>(
    () => GetTodoListUseCase(getIt<TodoRepository>()),
  );
}

// END GENERATED
