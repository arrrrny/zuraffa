import 'package:flutter/material.dart';

import '../controller/todo_controller.dart';

/// A simple list page displaying todos.
class TodoListPage extends StatefulWidget {
  final TodoController controller;

  const TodoListPage({super.key, required this.controller});

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadTodos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Todo Feature')),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final state = widget.controller.state;
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: state.todos.length,
            itemBuilder: (context, index) {
              final todo = state.todos[index];
              return ListTile(
                title: Text(todo['title'] as String),
                trailing: Checkbox(
                  value: todo['completed'] as bool? ?? false,
                  onChanged: (_) => widget.controller.toggleTodo(index),
                ),
                onLongPress: () => widget.controller.removeTodo(index),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => widget.controller.addTodo('New todo'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
