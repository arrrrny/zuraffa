import 'package:flutter/material.dart';
import 'package:zuraffa/zuraffa.dart';

import 'src/presentation/todo_page.dart';
import 'src/presentation/todo_presenter.dart';
import 'src/setup.dart';

void main() {
  Zuraffa.enableLogging();
  WidgetsFlutterBinding.ensureInitialized();

  setup().then((_) {
    runApp(const TodoApp());
  }).catchError((Object error, StackTrace st) {
    debugPrint('Setup failed: $error');
    debugPrintStack(stackTrace: st);
    runApp(const TodoApp());
  });
}

/// Minimal app shell that wires [TodoPage] with the injected [TodoPresenter].
class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zuraffa Todo Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: TodoPage(presenter: getIt<TodoPresenter>()),
    );
  }
}
