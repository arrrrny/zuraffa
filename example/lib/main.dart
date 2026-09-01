import 'package:flutter/material.dart';

import 'setup.dart';
import 'src/presentation/todo_controller.dart';
import 'src/presentation/todo_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = await setup();

  runApp(TodoApp(controller: controller));
}

/// Minimal app shell hosting [TodoPage].
class TodoApp extends StatelessWidget {
  const TodoApp({super.key, required this.controller});

  final TodoController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zuraffa Todo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: TodoPage(controller: controller),
    );
  }
}
