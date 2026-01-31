import 'package:example/src/data/data_sources/todo/in_memory_todo_datasource.dart';
import 'package:example/src/data/repositories/data_todo_repository.dart';
import 'package:example/src/presentation/pages/todo/todo_view.dart';
import 'package:flutter/material.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  // Enable framework logging in debug mode
  Zuraffa.enableLogging();

  runApp(const CleanArchitectureExampleApp());
}

/// Example app demonstrating Zuraffa v7.
///
/// This app shows:
/// - [UseCase] for single-shot operations (create, toggle, delete todos)
/// - [StreamUseCase] for real-time updates (watch todos)
/// - [BackgroundUseCase] for CPU-intensive work (calculate primes)
/// - [Controller] and [CleanView] for presentation layer
/// - [ControlledWidgetBuilder] for fine-grained UI updates
/// - [Result] and [AppFailure] for type-safe error handling
/// - [CancelToken] for cooperative cancellation
class CleanArchitectureExampleApp extends StatelessWidget {
  const CleanArchitectureExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zuraffa Clean Architecture Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: TodoView(
          todoRepository: DataTodoRepository(InMemoryTodoDataSource())),
    );
  }
}
