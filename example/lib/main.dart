import 'package:example/src/domain/domain.dart';
import 'package:example/src/presentation/pages/todo/todo_view.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:zuraffa/zuraffa.dart';
import './src/di/index.dart' as auto_di;
import './src/cache/index.dart' as auto_cache;

void main() async {
  // Enable framework logging in debug mode
  Zuraffa.enableLogging();
  await setupDependencies();
  runApp(const ZuraffaExampleApp());
}

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  auto_di.setupDependencies(getIt);
  await Hive.initFlutter();
  await Hive.deleteFromDisk();

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
      home: TodoView(
        todoRepository: getIt<TodoRepository>(),
      ),
    );
  }
}
