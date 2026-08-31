import 'package:flutter/material.dart';

import 'todo_controller.dart';
import 'todo_state.dart';

/// The Todo list page.
///
/// HAND-WRITTEN (spec 031 US4): pure presentation. Listens to
/// [TodoController] (a [ChangeNotifier] over the CLI-generated use
/// cases) and renders [TodoState].
class TodoPage extends StatefulWidget {
  const TodoPage({super.key, required this.controller});

  final TodoController controller;

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.watchTodoList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zuraffa Todo')),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final TodoState state = widget.controller.state;
          if (state.hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.error!.toString())));
              widget.controller.dismissError();
            });
          }
          if (state.isLoading && state.todoList.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.todoList.isEmpty) {
            return const Center(child: Text('No todos yet — add one!'));
          }
          return ListView.builder(
            itemCount: state.todoList.length,
            itemBuilder: (context, index) {
              final todo = state.todoList[index];
              return ListTile(
                leading: Checkbox(
                  value: todo.isCompleted,
                  onChanged: (_) => widget.controller.toggleTodo(todo),
                ),
                title: Text(
                  todo.title,
                  style: TextStyle(
                    decoration: todo.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                subtitle: Text('Priority: ${todo.priority.name}'),
                trailing: state.isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => widget.controller.deleteTodo(todo),
                      ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_titleController.text.trim().isNotEmpty) {
            widget.controller.createTodo(_titleController.text);
            _titleController.clear();
            return;
          }
          showModalBottomSheet<void>(
            context: context,
            builder: (_) => Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: TextField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'What needs to be done?',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  widget.controller.createTodo(value);
                  _titleController.clear();
                  Navigator.of(context).pop();
                },
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
