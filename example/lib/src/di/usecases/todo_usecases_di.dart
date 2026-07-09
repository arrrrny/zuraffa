import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/todo_repository.dart';
import '../../domain/usecases/todo/create_todo_usecase.dart';
import '../../domain/usecases/todo/delete_todo_usecase.dart';
import '../../domain/usecases/todo/get_todo_list_usecase.dart';
import '../../domain/usecases/todo/get_todo_usecase.dart';
import '../../domain/usecases/todo/update_todo_usecase.dart';
import '../../domain/usecases/todo/watch_todo_list_usecase.dart';
import '../../domain/usecases/todo/watch_todo_usecase.dart';

void registerAllTodoUseCases(GetIt getIt) {
  getIt.registerLazySingleton<CreateTodoUseCase>(
    () => CreateTodoUseCase(getIt<TodoRepository>()),
  );
  getIt.registerLazySingleton<DeleteTodoUseCase>(
    () => DeleteTodoUseCase(getIt<TodoRepository>()),
  );
  getIt.registerLazySingleton<GetTodoListUseCase>(
    () => GetTodoListUseCase(getIt<TodoRepository>()),
  );
  getIt.registerLazySingleton<GetTodoUseCase>(
    () => GetTodoUseCase(getIt<TodoRepository>()),
  );
  getIt.registerLazySingleton<UpdateTodoUseCase>(
    () => UpdateTodoUseCase(getIt<TodoRepository>()),
  );
  getIt.registerLazySingleton<WatchTodoListUseCase>(
    () => WatchTodoListUseCase(getIt<TodoRepository>()),
  );
  getIt.registerLazySingleton<WatchTodoUseCase>(
    () => WatchTodoUseCase(getIt<TodoRepository>()),
  );
}
