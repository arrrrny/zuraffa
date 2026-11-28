// dart format off
part of '../../../../../src/domain/entities/todo_stats/todo_stats.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class TodoStats implements ZorphyValueBase {
  const TodoStats.fromTrusted({
    required this.total,
    required this.active,
    required this.completed,
  });

  final int total;

  final int active;

  final int completed;

  static const TodoStatsLenses lenses = TodoStatsLenses();

  TodoStats copyWith({int? total, int? active, int? completed}) {
    return TodoStats.fromTrusted(
      total: total ?? this.total,
      active: active ?? this.active,
      completed: completed ?? this.completed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TodoStats &&
        this.total == other.total &&
        this.active == other.active &&
        this.completed == other.completed;
  }

  @override
  int get hashCode => Object.hashAll([total, active, completed]);

  @override
  String toString() =>
      'TodoStats(total: $total, active: $active, completed: $completed)';

  static ZorphyBoundaryResult<TodoStats> fromWire(Map<String, Object?> raw) {
    final violations = <FieldViolation>[];
    final Object? raw_total = raw['total'];
    int? _total;
    _total = _boundaryAs<int>(raw_total, '/total', violations);
    final Object? raw_active = raw['active'];
    int? _active;
    _active = _boundaryAs<int>(raw_active, '/active', violations);
    final Object? raw_completed = raw['completed'];
    int? _completed;
    _completed = _boundaryAs<int>(raw_completed, '/completed', violations);
    if (violations.isNotEmpty) {
      return BoundaryErr<TodoStats>(
        targetType: 'TodoStats',
        violations: violations,
      );
    }
    return BoundaryOk<TodoStats>(
      TodoStats.fromTrusted(
        total: _total!,
        active: _active!,
        completed: _completed!,
      ),
    );
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{};
    map['total'] = this.total;
    map['active'] = this.active;
    map['completed'] = this.completed;
    return map;
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [TodoStats].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<TodoStats, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      '/total' => ZorphyLens<TodoStats, Object?>(
        path: '/total',
        get: (root) => root.total,
        set: (root, value) => root.copyWith(total: value as int),
      ),
      '/active' => ZorphyLens<TodoStats, Object?>(
        path: '/active',
        get: (root) => root.active,
        set: (root, value) => root.copyWith(active: value as int),
      ),
      '/completed' => ZorphyLens<TodoStats, Object?>(
        path: '/completed',
        get: (root) => root.completed,
        set: (root, value) => root.copyWith(completed: value as int),
      ),
      _ => null,
    };
  }
}

class TodoStatsMockData {
  TodoStatsMockData._();

  static TodoStats single({int seed = 0}) {
    return TodoStats.fromTrusted(
      total: seed % 97 + 828,
      active: seed % 97 + 646,
      completed: seed % 97 + 987,
    );
  }

  static List<TodoStats> list({int count = 10}) {
    return List<TodoStats>.generate(count, (index) => single(seed: index));
  }
}

String _boundaryDescribe(Object? value) {
  if (value == null) return 'null';
  final text = value.toString();
  final clipped = text.length > 60 ? '${text.substring(0, 60)}…' : text;
  return '${value.runtimeType} ("$clipped")';
}

T? _boundaryAs<T>(Object? value, String path, List<FieldViolation> violations) {
  if (value is T) return value;
  violations.add(
    FieldViolation(
      path: path,
      expected: '$T',
      actual: _boundaryDescribe(value),
    ),
  );
  return null;
}

/// Typed lenses over [TodoStats] — one per writable field.
///
/// Compose with `then` to reach a nested value:
/// `TodoStats.lenses.<field>.then(<Nested>.lenses.<leaf>)`.
final class TodoStatsLenses {
  const TodoStatsLenses();

  ZorphyLens<TodoStats, int> get total => const ZorphyLens<TodoStats, int>(
    path: '/total',
    get: _getTotal,
    set: _setTotal,
  );

  static int _getTotal(TodoStats root) => root.total;

  static TodoStats _setTotal(TodoStats root, int value) =>
      root.copyWith(total: value);

  ZorphyLens<TodoStats, int> get active => const ZorphyLens<TodoStats, int>(
    path: '/active',
    get: _getActive,
    set: _setActive,
  );

  static int _getActive(TodoStats root) => root.active;

  static TodoStats _setActive(TodoStats root, int value) =>
      root.copyWith(active: value);

  ZorphyLens<TodoStats, int> get completed => const ZorphyLens<TodoStats, int>(
    path: '/completed',
    get: _getCompleted,
    set: _setCompleted,
  );

  static int _getCompleted(TodoStats root) => root.completed;

  static TodoStats _setCompleted(TodoStats root, int value) =>
      root.copyWith(completed: value);
}

