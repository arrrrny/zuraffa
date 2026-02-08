// Auto-generated cache for Todo
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../domain/entities/todo/todo.dart';

Future<void> initTodoCache() async {
  await Hive.openBox<Todo>('todos');
}
