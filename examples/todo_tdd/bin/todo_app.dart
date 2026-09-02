import 'package:todo_tdd/src/domain/entities/todo/todo.dart';
import 'package:todo_tdd/src/domain/entities/todo_stats/todo_stats.dart';
import 'package:todo_tdd/tdd/a3_subject.dart' as a3;
import 'package:todo_tdd/tdd/u1_subject.dart' as u1;
import 'package:todo_tdd/tdd/u2_subject.dart' as u2;
import 'package:todo_tdd/tdd/u3_subject.dart' as u3;
import 'package:todo_tdd/tdd/u4_subject.dart' as u4;
import 'package:todo_tdd/tdd/u5_subject.dart' as u5;
import 'package:todo_tdd/tdd/u6_subject.dart' as u6;

/// Todo app — presentation shell over the zfa-tdd-generated domain.
///
/// Every artifact imported here was produced by the `zfa tdd` cycle:
///   - `Todo` / `TodoStats` entities: `zfa entity create` (behavior make
///     step A1/A2) + explicit field schema via `zfa entity create --field`.
///   - domain helper functions: `zfa tdd func` (unit behaviors U1-U6,
///     A3) — each red-verified, then generated green by `zfa tdd make`.
/// This file contains assembly/presentation logic only — no domain rules.
void main() {
  final now = DateTime.now();
  final todos = <Todo>[
    Todo(
      id: 't-1',
      title: 'Scaffold the app with zfa setup',
      description: 'zfa setup todo_tdd --dart',
      isCompleted: true,
      priority: u1.subject_u1(),
      tags: const ['setup'],
      createdAt: now,
      completedAt: now,
    ),
    Todo(
      id: 't-2',
      title: 'Drive 001-todo-app through the tdd cycle',
      description: 'zfa tdd run 001-todo-app',
      isCompleted: true,
      priority: u1.subject_u1(),
      tags: const ['tdd', 'cycle'],
      createdAt: now,
      completedAt: now,
    ),
    Todo(
      id: 't-3',
      title: 'Verify the app runs green',
      description: 'dart test && dart run bin/todo_app.dart',
      isCompleted: false,
      priority: 2,
      tags: const ['verify', 'green'],
      createdAt: now,
      completedAt: now,
    ),
  ];

  // Title validation against the generated maximum (U2).
  final maxTitleLength = u2.subject_u2();
  for (final todo in todos) {
    if (todo.title.length > maxTitleLength) {
      throw StateError(
        'todo ${todo.id}: title exceeds the $maxTitleLength character limit',
      );
    }
  }

  // Aggregate stats over the seeded list (TodoStats entity, A2).
  final stats = TodoStats(
    total: todos.length,
    active: todos.where((t) => !t.isCompleted).length,
    completed: todos.where((t) => t.isCompleted).length,
  );

  // Persistence flag (U6) — the journal is clean when tests are green.
  final journalClean = u6.subject_u6();

  print(a3.subject_a3());
  print('persistence journal clean: $journalClean');
  print('');
  print('todos (${stats.total} total, ${stats.active} active, '
      '${stats.completed} completed):');
  for (final todo in todos) {
    final marker = todo.isCompleted ? '[x]' : '[ ]';
    print('  $marker ${todo.id}  ${todo.title}');
    print('      priority: ${todo.priority} (${u3.subject_u3()})'
        '  tags: ${todo.tags.isEmpty ? '-' : todo.tags.join(', ')}');
  }
  print('');
  print('completion ratio (U5, empty-list case): ${u5.subject_u5()}');
  print('overdue tags (U4): ${u4.subject_u4().join(', ')}');
}
