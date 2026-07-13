import 'package:example/src/domain/domain.dart';
import 'package:example/src/presentation/pages/todo/todo_view.dart';
import 'package:flutter/material.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:example/src/api/bridges/todo_api_bridge.dart';
import './src/di/index.dart' as auto_di;
import './src/cache/index.dart' as auto_cache;

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  auto_di.setupDependencies(getIt);
  await Hive.initFlutter();
  await auto_cache.initAllCaches();
}

void _initializeBridge() {
  ZuraffaApiBridge.init();
  registerTodoApiBridge();
}

void main() {
  Zuraffa.enableLogging();
  WidgetsFlutterBinding.ensureInitialized();
  setupDependencies()
      .then((_) {
        runApp(const ZuraffaExampleApp());
        _initializeBridge();
      })
      .catchError((Object error, StackTrace st) {
        debugPrint('❌ setupDependencies failed: $error');
        debugPrintStack(stackTrace: st);
        runApp(const ZuraffaExampleApp());
        _initializeBridge();
      });
}

/// Example app demonstrating Zuraffa Clean Architecture.
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
