// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'todo_stats.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class TodoStats {
  TodoStats({
    required int this.total,
    required int this.active,
    required int this.completed,
  });

  factory TodoStats.fromJson(Map<String, dynamic> json) =>
      _$TodoStatsFromJson(json);

  final int total;

  final int active;

  final int completed;

  TodoStats copyWith({int? total, int? active, int? completed}) {
    return TodoStats(
      total: total ?? this.total,
      active: active ?? this.active,
      completed: completed ?? this.completed,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  TodoStats copyWithField<T>(Field<TodoStats, T> field, T value) {
    switch (field.name) {
      case 'total':
        return copyWith(total: value as int);
      case 'active':
        return copyWith(active: value as int);
      case 'completed':
        return copyWith(completed: value as int);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'TodoStats has no settable field with this name',
        );
    }
  }

  TodoStats copyWithTodoStats({int? total, int? active, int? completed}) {
    return copyWith(total: total, active: active, completed: completed);
  }

  TodoStats patchWithTodoStats([TodoStatsPatch? patchInput]) {
    final _patcher = patchInput ?? TodoStatsPatch();
    final _patchMap = _patcher.patchMap;
    return TodoStats(
      total: _patchMap.containsKey(TodoStats$.total)
          ? ((_patchMap[TodoStats$.total] is Function)
                    ? _patchMap[TodoStats$.total](this.total)
                    : (_patchMap[TodoStats$.total] is Patch)
                    ? _patchMap[TodoStats$.total].applyTo(this.total)
                    : _patchMap[TodoStats$.total])
                as int
          : this.total,
      active: _patchMap.containsKey(TodoStats$.active)
          ? ((_patchMap[TodoStats$.active] is Function)
                    ? _patchMap[TodoStats$.active](this.active)
                    : (_patchMap[TodoStats$.active] is Patch)
                    ? _patchMap[TodoStats$.active].applyTo(this.active)
                    : _patchMap[TodoStats$.active])
                as int
          : this.active,
      completed: _patchMap.containsKey(TodoStats$.completed)
          ? ((_patchMap[TodoStats$.completed] is Function)
                    ? _patchMap[TodoStats$.completed](this.completed)
                    : (_patchMap[TodoStats$.completed] is Patch)
                    ? _patchMap[TodoStats$.completed].applyTo(this.completed)
                    : _patchMap[TodoStats$.completed])
                as int
          : this.completed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TodoStats &&
        total == other.total &&
        active == other.active &&
        completed == other.completed;
  }

  @override
  int get hashCode {
    return Object.hash(this.total, this.active, this.completed);
  }

  @override
  String toString() {
    return 'TodoStats(' +
        'total: ${total}' +
        ', ' +
        'active: ${active}' +
        ', ' +
        'completed: ${completed})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$TodoStatsToJson(this);
    _sanitizeJson(data);
    return data;
  }

  dynamic _sanitizeJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      json.remove('__typename');
      return json..forEach((key, value) {
        json[key] = _sanitizeJson(value);
      });
    } else if (json is List) {
      return json.map((e) => _sanitizeJson(e)).toList();
    }
    return json;
  }
}

extension TodoStatsPropertyHelpers on TodoStats {}

extension TodoStatsSerialization on TodoStats {
  Map<String, dynamic> toJson() {
    return _$TodoStatsToJson(this);
  }
}

enum TodoStats$ { total, active, completed }

class TodoStatsPatch extends PatchBase<TodoStats, TodoStats$> {
  TodoStats applyTo(TodoStats entity) {
    return entity.patchWithTodoStats(this);
  }

  TodoStatsPatch withTotal(int? value) {
    patchMap[TodoStats$.total] = value;
    return this;
  }

  TodoStatsPatch withActive(int? value) {
    patchMap[TodoStats$.active] = value;
    return this;
  }

  TodoStatsPatch withCompleted(int? value) {
    patchMap[TodoStats$.completed] = value;
    return this;
  }
}

/// Field descriptors for [TodoStats] query construction
abstract final class TodoStatsFields {
  static const total = Field<TodoStats, int>('total', _$total);

  static const active = Field<TodoStats, int>('active', _$active);

  static const completed = Field<TodoStats, int>('completed', _$completed);

  static int _$total(TodoStats e) {
    return e.total;
  }

  static int _$active(TodoStats e) {
    return e.active;
  }

  static int _$completed(TodoStats e) {
    return e.completed;
  }
}

extension TodoStatsCompareE on TodoStats {
  Map<String, dynamic> compareToTodoStats(TodoStats other) {
    final Map<String, dynamic> diff = {};

    if (total != other.total) {
      diff['total'] = () => other.total;
    }

    if (active != other.active) {
      diff['active'] = () => other.active;
    }

    if (completed != other.completed) {
      diff['completed'] = () => other.completed;
    }
    return diff;
  }
}
