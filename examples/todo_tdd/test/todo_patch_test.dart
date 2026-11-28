import 'dart:convert';

import 'package:test/test.dart';
import 'package:todo_tdd/src/domain/entities/todo/todo.dart';

void main() {
  test('snapshots replacement and inverse tags at patch construction', () {
    final updatedTags = ['updated'];
    final originalTags = ['original'];
    final before = Todo.fromTrusted(
      id: 'todo',
      title: 'Todo',
      description: '',
      isCompleted: false,
      priority: 1,
      tags: originalTags,
      createdAt: DateTime.utc(2026),
      completedAt: DateTime.utc(2026),
    );
    final patch = TodoPatch().withTags(updatedTags);
    final inverse = patch.invert(before);

    updatedTags.clear();
    originalTags.clear();

    expect(patch.toWire()['tags'], ['updated']);
    expect(inverse.toWire()['tags'], ['original']);
    expect(() => patch.tags.valueOrNull!.clear(), throwsUnsupportedError);
    expect(() => inverse.tags.valueOrNull!.clear(), throwsUnsupportedError);
    expect(TodoPatch().toWire(), isEmpty);
  });

  test('decodes JSON tag replacements including empty arrays', () {
    for (final json in ['{"tags":["todo"]}', '{"tags":[]}']) {
      final raw = jsonDecode(json) as Map<String, dynamic>;
      final patch = TodoPatch.fromWire(raw).fold(
        (value) => value,
        (error) => throw StateError('${error.violations}'),
      );
      expect(patch.toWire(), raw);
    }
  });

  test('reports the index of a malformed tag replacement element', () {
    final paths =
        TodoPatch.fromWire({
          'tags': ['valid', 42],
        }).fold(
          (_) => <String>[],
          (error) => [for (final violation in error.violations) violation.path],
        );
    expect(paths, ['/tags[1]']);
  });
}
