import 'package:get_it/get_it.dart';
import 'package:zuraffa/zuraffa.dart';

import '../datasource/todo_local_datasource.dart';
import '../interceptor/logging_interceptor.dart';
import '../repository/todo_repository.dart';
import '../usecase/get_todos_usecase_contract.dart';
import '../usecase/default_get_todos_usecase.dart';
import '../controller/todo_controller.dart';
import '../view/todo_list_page.dart';

/// Orchestrator plugin for the example todo feature.
///
/// Demonstrates:
/// - DI override via `override: true` on [registerLazySingleton].
/// - UseCase interceptor registration via [registerInterceptor].
/// - Abstract contract + default implementation split.
class ExampleFeaturePlugin extends ZuraffaPlugin {
  @override
  String get pluginId => 'example_todo';

  @override
  void registerDependencies(ZuraffaDIContainer di) {
    di.registerLazySingleton<TodoLocalDataSource>(
      () => TodoLocalDataSource()..seed(),
    );

    di.registerLazySingleton<TodoRepository>(
      () => TodoRepositoryImpl(di.get()),
    );

    // Register the UseCase contract bound to its default implementation.
    // A plugin could later override this with `override: true`.
    di.registerLazySingleton<GetTodosUseCase>(
      () => DefaultGetTodosUseCase(
        di.get(),
        interceptorRegistry: di.interceptorRegistry,
      ),
    );

    // Register an interceptor for the GetTodosUseCase pipeline.
    di.registerInterceptor<void, List<dynamic>>(
      loggingInterceptor(),
    );

    di.registerFactory<TodoController>(
      () => TodoController(di.get()),
    );
  }

  @override
  Map<String, ZuraffaRouteBuilder> get routes => {
        '/todos': (context, args) {
          final controller = GetIt.instance<TodoController>();
          return TodoListPage(controller: controller);
        },
      };
}
