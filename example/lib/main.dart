import 'dart:convert';
import 'dart:developer' as developer;

import 'package:example/src/domain/domain.dart';
import 'package:example/src/domain/entities/todo/todo.dart';
import 'package:example/src/domain/usecases/todo/create_todo_usecase.dart';
import 'package:example/src/presentation/pages/todo/todo_view.dart';
import 'package:flutter/material.dart';
import 'package:zuraffa/zuraffa.dart';
import './src/di/index.dart' as auto_di;
import './src/cache/index.dart' as auto_cache;

void main() async {
  // Enable framework logging in debug mode
  Zuraffa.enableLogging();
  await setupDependencies();
  runApp(const ZuraffaExampleApp());

  // Register a VM Service Extension for debug/profile builds only.
  // This is stripped from release builds.
  assert(() {
    _registerDebugUseCaseExtensions();
    return true;
  }());
}

/// Registers VM Service Extension handlers that let you invoke UseCases
/// from the command line while the app is running.
///
/// Example curl (replace PORT with the VM service port printed by `flutter run`):
///
/// ```bash
/// curl -X POST http://127.0.0.1:PORT/ \
///   -H 'Content-Type: application/json' \
///   -d '{
///     "jsonrpc": "2.0",
///     "method": "ext.zuraffa.addTodo",
///     "params": {
///       "json": "{\"id\":42,\"title\":\"From curl\",\"isCompleted\":false,\"createdAt\":\"2026-07-09T10:00:00.000\"}"
///     },
///     "id": 1
///   }'
/// ```
///
/// Or pass individual fields:
/// ```bash
/// curl -X POST http://127.0.0.1:PORT/ \
///   -H 'Content-Type: application/json' \
///   -d '{
///     "jsonrpc": "2.0",
///     "method": "ext.zuraffa.addTodo",
///     "params": {"id":"42","title":"From curl","isCompleted":"false"},
///     "id": 1
///   }'
/// ```
void _registerDebugUseCaseExtensions() {
  developer.registerExtension('ext.zuraffa.addTodo', (
    method,
    parameters,
  ) async {
    try {
      final todo = _parseTodoFromParams(parameters);
      final createTodoUseCase = getIt<CreateTodoUseCase>();
      final result = await createTodoUseCase(todo);

      return result.fold(
        (createdTodo) => developer.ServiceExtensionResponse.result(
          jsonEncode({'status': 'success', 'data': createdTodo.toJsonLean()}),
        ),
        (failure) => developer.ServiceExtensionResponse.result(
          jsonEncode({
            'status': 'failure',
            'failure': {
              'type': failure.runtimeType.toString(),
              'message': failure.message,
            },
          }),
        ),
      );
    } catch (e, stackTrace) {
      return developer.ServiceExtensionResponse.result(
        jsonEncode({
          'status': 'error',
          'message': e.toString(),
          'stackTrace': stackTrace.toString(),
        }),
      );
    }
  });
}

/// Parses a [Todo] from the VM Service extension parameters.
///
/// Supports either a single `json` parameter containing a JSON-encoded Todo,
/// or individual `id`, `title`, `isCompleted`, and `createdAt` parameters.
Todo _parseTodoFromParams(Map<String, String> parameters) {
  if (parameters.containsKey('json')) {
    final jsonString = parameters['json'];
    if (jsonString == null || jsonString.isEmpty) {
      throw ArgumentError('Missing json parameter');
    }
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return Todo.fromJson(json);
  }

  final id = parameters['id'];
  final title = parameters['title'];
  if (id == null || id.isEmpty) {
    throw ArgumentError('Missing id parameter');
  }
  if (title == null || title.isEmpty) {
    throw ArgumentError('Missing title parameter');
  }

  return Todo(
    id: int.parse(id),
    title: title,
    isCompleted: parameters['isCompleted']?.toLowerCase() == 'true',
    createdAt: parameters['createdAt'] != null
        ? DateTime.parse(parameters['createdAt']!)
        : DateTime.now(),
  );
}

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  auto_di.setupDependencies(getIt);
  await Hive.initFlutter();
  await auto_cache.initAllCaches();
}

/// Example app demonstrating Zuraffa.
///
/// This app shows:
/// - [UseCase] for single-shot operations (create, toggle, delete todos)
/// - [StreamUseCase] for real-time updates (watch todos)
/// - [BackgroundUseCase] for CPU-intensive work (calculate primes)
/// - [Controller] and [CleanView] for presentation layer
/// - [ControlledWidgetBuilder] for fine-grained UI updates
/// - [Result] and [AppFailure] for type-safe error handling
/// - [CancelToken] for cooperative cancellation
class ZuraffaExampleApp extends StatelessWidget {
  const ZuraffaExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zuraffa Clean Architecture Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: TodoView(todoRepository: getIt<TodoRepository>()),
    );
  }
}
