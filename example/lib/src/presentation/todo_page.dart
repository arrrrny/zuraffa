// ignore_for_file: no_logic_in_create_state

import 'package:flutter/material.dart';
import 'package:zuraffa/zuraffa.dart';

import '../domain/domain.dart';
import 'todo_controller.dart';
import 'todo_presenter.dart';
import 'todo_state.dart';

/// Full-featured Todo demo showcasing zorphy v2.1 + zuraffa.
///
/// Demonstrates:
/// - **zorphy**: [TodoFields] filter descriptors, [TodoPatch] for
///   partial updates, [TodoPriority] enum, [List<String>] collection,
///   property helpers (`hasTitle`, `noDescription`, `hasTags`),
///   [compareToTodo] diff tracking.
/// - **zuraffa**: [Controller] + [StatefulController] state management,
///   [Presenter] use case orchestration, [CleanView] / [CleanViewState]
///   widget lifecycle, [ControlledWidgetBuilder] / [ControlledWidgetSelector]
///   for fine-grained rebuilds, [Result] type-safe error handling,
///   [Loggable] / [FailureHandler] mixins.
class TodoPage extends CleanView {
  final TodoPresenter presenter;

  const TodoPage({super.key, super.routeObserver, required this.presenter});

  @override
  State<TodoPage> createState() => _TodoPageState(TodoController(presenter));
}

class _TodoPageState
    extends CleanViewState<TodoPage, TodoController, TodoState> {
  _TodoPageState(super.controller);

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  TodoPriority _selectedPriority = TodoPriority.medium;
  final List<String> _tags = [];

  @override
  void onInitState() {
    super.onInitState();
    controller.watchTodoList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget get view => Scaffold(
    key: globalKey,
    appBar: AppBar(
      title: const Text('Zuraffa Todo Demo'),
      actions: [
        PopupMenuButton<TodoPriority?>(
          icon: const Icon(Icons.filter_list),
          tooltip: 'Filter by priority',
          onSelected: (priority) {
            if (priority == null) {
              controller.clearFilter();
            } else {
              controller.watchTodoList(priority);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: null, child: Text('All')),
            for (final p in TodoPriority.values)
              PopupMenuItem(value: p, child: Text(p.name.capitalize())),
          ],
        ),
      ],
    ),
    body: Column(
      children: [
        _buildErrorBanner(),
        _buildActiveFilterChip(),
        _buildCreateForm(),
        Expanded(child: _buildTodoList()),
        _buildStatsFooter(),
      ],
    ),
  );

  // ── Error banner ──────────────────────────────────────────

  Widget _buildErrorBanner() {
    return ControlledWidgetSelector<TodoController, AppFailure?>(
      selector: (c) => c.viewState.error,
      builder: (context, error) {
        if (error == null) return const SizedBox.shrink();
        return MaterialBanner(
          backgroundColor: Colors.red.shade100,
          content: Text(error.message, style: TextStyle(color: Colors.red.shade900)),
          actions: [
            TextButton(
              onPressed: controller.clearError,
              child: const Text('DISMISS'),
            ),
          ],
        );
      },
    );
  }

  // ── Active filter chip ────────────────────────────────────

  Widget _buildActiveFilterChip() {
    return ControlledWidgetSelector<TodoController, TodoPriority?>(
      selector: (c) => c.viewState.activeFilter,
      builder: (context, filter) {
        if (filter == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Chip(
            avatar: const Icon(Icons.filter_alt, size: 18),
            label: Text('Priority: ${filter.name}'),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: controller.clearFilter,
          ),
        );
      },
    );
  }

  // ── Create form ───────────────────────────────────────────

  Widget _buildCreateForm() {
    return ControlledWidgetSelector<TodoController, bool>(
      selector: (c) => c.viewState.isCreating,
      builder: (context, isCreating) {
        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'What needs to be done?',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.task_alt),
                  ),
                  onSubmitted: (_) => _createTodo(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    hintText: 'Description (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Priority: '),
                    const SizedBox(width: 8),
                    SegmentedButton<TodoPriority>(
                      segments: const [
                        ButtonSegment(value: TodoPriority.low, label: Text('Low')),
                        ButtonSegment(value: TodoPriority.medium, label: Text('Medium')),
                        ButtonSegment(value: TodoPriority.high, label: Text('High')),
                      ],
                      selected: {_selectedPriority},
                      onSelectionChanged: (s) =>
                          setState(() => _selectedPriority = s.first),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        decoration: const InputDecoration(
                          hintText: 'Add tag (Enter to add)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.label),
                          isDense: true,
                        ),
                        onSubmitted: _addTag,
                      ),
                    ),
                  ],
                ),
                if (_tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 6,
                      children: _tags.map((tag) {
                        return Chip(
                          label: Text(tag, style: const TextStyle(fontSize: 12)),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(() => _tags.remove(tag)),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: isCreating ? null : _createTodo,
                    icon: isCreating
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: Text(isCreating ? 'Creating...' : 'Add Todo'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Todo list ─────────────────────────────────────────────

  Widget _buildTodoList() {
    return ControlledWidgetBuilder<TodoController>(
      builder: (context, controller) {
        final state = controller.viewState;

        if (state.isLoading && state.todoList.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.todoList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('No todos yet!', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Text('Add one above to get started.', style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: state.todoList.length,
          itemBuilder: (context, index) => _buildTodoItem(state.todoList[index]),
        );
      },
    );
  }

  Widget _buildTodoItem(Todo todo) {
    final color = switch (todo.priority) {
      TodoPriority.high => Colors.red,
      TodoPriority.medium => Colors.orange,
      TodoPriority.low => Colors.green,
    };

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => controller.deleteTodo(todo.id),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Priority color bar
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Checkbox(
                    value: todo.isCompleted,
                    onChanged: (_) => controller.toggleTodo(todo.id),
                  ),
                  Expanded(
                    child: Text(
                      todo.title,
                      style: TextStyle(
                        fontSize: 16,
                        decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                        color: todo.isCompleted ? Colors.grey : null,
                      ),
                    ),
                  ),
                  // Priority badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      todo.priority.name.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
                ],
              ),
              // Description (using zorphy property helper)
              if (todo.hasDescription) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 44, top: 4),
                  child: Text(
                    todo.description,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ),
              ],
              // Tags (using zorphy property helper)
              if (todo.hasTags) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 44, top: 6),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: todo.tags.map((tag) {
                      return Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 11)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.only(left: 6, right: 4),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ),
              ],
              // Timestamps
              Padding(
                padding: const EdgeInsets.only(left: 44, top: 6),
                child: Row(
                  children: [
                    Text(
                      _formatDate(todo.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    if (todo.isCompleted) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle, size: 12, color: Colors.green.shade400),
                      Text(
                        'done ${_formatDate(todo.completedAt)}',
                        style: TextStyle(fontSize: 11, color: Colors.green.shade600),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stats footer ──────────────────────────────────────────

  Widget _buildStatsFooter() {
    return ControlledWidgetSelector<TodoController, TodoState>(
      selector: (c) => c.viewState,
      builder: (context, state) {
        if (state.todoList.isEmpty) return const SizedBox.shrink();

        // Using zorphy-generated TodoFields for type-safe filtering
        final active = state.todoList.filter(TodoFields.isCompleted.eq(false)).length;
        final completed = state.todoList.filter(TodoFields.isCompleted.eq(true)).length;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$active active', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 24),
              Text('$completed completed', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(width: 24),
              Text(
                '${state.todoList.length} total',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────

  void _addTag(String tag) {
    if (tag.isNotEmpty && _tags.length < 5) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _createTodo() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final now = DateTime.now();
    final todo = Todo(
      id: now.microsecondsSinceEpoch,
      title: title,
      description: _descriptionController.text.trim(),
      isCompleted: false,
      priority: _selectedPriority,
      tags: List.unmodifiable(_tags),
      createdAt: now,
      completedAt: now,
    );

    controller.createTodo(todo).then((_) {
      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _tags.clear();
        _selectedPriority = TodoPriority.medium;
      });
    });
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

extension StringCapitalize on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
