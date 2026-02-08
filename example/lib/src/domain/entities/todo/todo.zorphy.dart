// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'todo.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true)
class Todo {
  final int id;
  final String title;
  final bool isCompleted;
  final DateTime createdAt;

  Todo({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.createdAt,
  });

  Todo copyWith({
    int? id,
    String? title,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Todo copyWithTodo({
    int? id,
    String? title,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return copyWith(
      id: id,
      title: title,
      isCompleted: isCompleted,
      createdAt: createdAt,
    );
  }

  Todo patchWithTodo({
    TodoPatch? patchInput,
  }) {
    final _patcher = patchInput ?? TodoPatch();
    final _patchMap = _patcher.toPatch();
    return Todo(
        id: _patchMap.containsKey(Todo$.id)
            ? (_patchMap[Todo$.id] is Function)
                ? _patchMap[Todo$.id](this.id)
                : _patchMap[Todo$.id]
            : this.id,
        title: _patchMap.containsKey(Todo$.title)
            ? (_patchMap[Todo$.title] is Function)
                ? _patchMap[Todo$.title](this.title)
                : _patchMap[Todo$.title]
            : this.title,
        isCompleted: _patchMap.containsKey(Todo$.isCompleted)
            ? (_patchMap[Todo$.isCompleted] is Function)
                ? _patchMap[Todo$.isCompleted](this.isCompleted)
                : _patchMap[Todo$.isCompleted]
            : this.isCompleted,
        createdAt: _patchMap.containsKey(Todo$.createdAt)
            ? (_patchMap[Todo$.createdAt] is Function)
                ? _patchMap[Todo$.createdAt](this.createdAt)
                : _patchMap[Todo$.createdAt]
            : this.createdAt);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Todo &&
        id == other.id &&
        title == other.title &&
        isCompleted == other.isCompleted &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(this.id, this.title, this.isCompleted, this.createdAt);
  }

  @override
  String toString() {
    return 'Todo(' +
        'id: ${id}' +
        ', ' +
        'title: ${title}' +
        ', ' +
        'isCompleted: ${isCompleted}' +
        ', ' +
        'createdAt: ${createdAt})';
  }

  /// Creates a [Todo] instance from JSON
  factory Todo.fromJson(Map<String, dynamic> json) => _$TodoFromJson(json);

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$TodoToJson(this);
    return _sanitizeJson(data);
  }

  dynamic _sanitizeJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      json.remove('_className_');
      return json
        ..forEach((key, value) {
          json[key] = _sanitizeJson(value);
        });
    } else if (json is List) {
      return json.map((e) => _sanitizeJson(e)).toList();
    }
    return json;
  }
}

extension TodoSerialization on Todo {
  Map<String, dynamic> toJson() => _$TodoToJson(this);
  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$TodoToJson(this);
    return _sanitizeJson(data);
  }

  dynamic _sanitizeJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      json.remove('_className_');
      return json
        ..forEach((key, value) {
          json[key] = _sanitizeJson(value);
        });
    } else if (json is List) {
      return json.map((e) => _sanitizeJson(e)).toList();
    }
    return json;
  }
}

enum Todo$ { id, title, isCompleted, createdAt }

class TodoPatch implements Patch<Todo> {
  final Map<Todo$, dynamic> _patch = {};

  static TodoPatch create([Map<String, dynamic>? diff]) {
    final patch = TodoPatch();
    if (diff != null) {
      diff.forEach((key, value) {
        try {
          final enumValue = Todo$.values.firstWhere((e) => e.name == key);
          if (value is Function) {
            patch._patch[enumValue] = value();
          } else {
            patch._patch[enumValue] = value;
          }
        } catch (_) {}
      });
    }
    return patch;
  }

  static TodoPatch fromPatch(Map<Todo$, dynamic> patch) {
    final _patch = TodoPatch();
    _patch._patch.addAll(patch);
    return _patch;
  }

  Map<Todo$, dynamic> toPatch() => Map.from(_patch);

  Todo applyTo(Todo entity) {
    return entity.patchWithTodo(patchInput: this);
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    _patch.forEach((key, value) {
      if (value != null) {
        if (value is Function) {
          final result = value();
          json[key.name] = _convertToJson(result);
        } else {
          json[key.name] = _convertToJson(value);
        }
      }
    });
    return json;
  }

  dynamic _convertToJson(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    if (value is Enum) return value.toString().split('.').last;
    if (value is List) return value.map((e) => _convertToJson(e)).toList();
    if (value is Map)
      return value.map((k, v) => MapEntry(k.toString(), _convertToJson(v)));
    if (value is num || value is bool || value is String) return value;
    try {
      if (value?.toJsonLean != null) return value.toJsonLean();
    } catch (_) {}
    if (value?.toJson != null) return value.toJson();
    return value.toString();
  }

  static TodoPatch fromJson(Map<String, dynamic> json) {
    return create(json);
  }

  TodoPatch withId(int? value) {
    _patch[Todo$.id] = value;
    return this;
  }

  TodoPatch withTitle(String? value) {
    _patch[Todo$.title] = value;
    return this;
  }

  TodoPatch withIsCompleted(bool? value) {
    _patch[Todo$.isCompleted] = value;
    return this;
  }

  TodoPatch withCreatedAt(DateTime? value) {
    _patch[Todo$.createdAt] = value;
    return this;
  }
}

/// Field descriptors for [Todo] query construction
abstract final class TodoFields {
  static int _$getid(Todo e) => e.id;
  static const id = Field<Todo, int>('id', _$getid);
  static String _$gettitle(Todo e) => e.title;
  static const title = Field<Todo, String>('title', _$gettitle);
  static bool _$getisCompleted(Todo e) => e.isCompleted;
  static const isCompleted = Field<Todo, bool>('isCompleted', _$getisCompleted);
  static DateTime _$getcreatedAt(Todo e) => e.createdAt;
  static const createdAt = Field<Todo, DateTime>('createdAt', _$getcreatedAt);
}

extension TodoCompareE on Todo {
  Map<String, dynamic> compareToTodo(Todo other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }
    if (title != other.title) {
      diff['title'] = () => other.title;
    }
    if (isCompleted != other.isCompleted) {
      diff['isCompleted'] = () => other.isCompleted;
    }
    if (createdAt != other.createdAt) {
      diff['createdAt'] = () => other.createdAt;
    }
    return diff;
  }
}
