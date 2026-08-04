import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:zuraffa/zuraffa.dart';

import '../datasource/todo_local_datasource.dart';
import '../repository/todo_repository.dart';
import '../usecase/get_todos_usecase.dart';
import '../controller/todo_controller.dart';
import '../view/todo_list_page.dart';

/// Orchestrator plugin for the example todo feature.
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
    di.registerLazySingleton<GetTodosUseCase>(
      () => GetTodosUseCase(di.get()),
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
