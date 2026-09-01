// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'todo.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class Todo {
  Todo({
    required int this.id,
    required String this.title,
    required String this.description,
    required bool this.isCompleted,
    required TodoPriority this.priority,
    required List<String> this.tags,
    required DateTime this.createdAt,
    required DateTime this.completedAt,
  });

  factory Todo.fromJson(Map<String, dynamic> json) => _$TodoFromJson(json);

  final int id;

  final String title;

  final String description;

  final bool isCompleted;

  final TodoPriority priority;

  final List<String> tags;

  final DateTime createdAt;

  final DateTime completedAt;

  Todo copyWith({
    int? id,
    String? title,
    String? description,
    bool? isCompleted,
    TodoPriority? priority,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  Todo copyWithField<T>(Field<Todo, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as int);
      case 'title':
        return copyWith(title: value as String);
      case 'description':
        return copyWith(description: value as String);
      case 'isCompleted':
        return copyWith(isCompleted: value as bool);
      case 'priority':
        return copyWith(priority: value as TodoPriority);
      case 'tags':
        return copyWith(tags: value as List<String>);
      case 'createdAt':
        return copyWith(createdAt: value as DateTime);
      case 'completedAt':
        return copyWith(completedAt: value as DateTime);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'Todo has no settable field with this name',
        );
    }
  }

  Todo copyWithTodo({
    int? id,
    String? title,
    String? description,
    bool? isCompleted,
    TodoPriority? priority,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return copyWith(
      id: id,
      title: title,
      description: description,
      isCompleted: isCompleted,
      priority: priority,
      tags: tags,
      createdAt: createdAt,
      completedAt: completedAt,
    );
  }

  Todo patchWithTodo([TodoPatch? patchInput]) {
    final _patcher = patchInput ?? TodoPatch();
    final _patchMap = _patcher.patchMap;
    return Todo(
      id: _patchMap.containsKey(Todo$.id)
          ? ((_patchMap[Todo$.id] is Function)
                    ? _patchMap[Todo$.id](this.id)
                    : (_patchMap[Todo$.id] is Patch)
                    ? _patchMap[Todo$.id].applyTo(this.id)
                    : _patchMap[Todo$.id])
                as int
          : this.id,
      title: _patchMap.containsKey(Todo$.title)
          ? ((_patchMap[Todo$.title] is Function)
                    ? _patchMap[Todo$.title](this.title)
                    : (_patchMap[Todo$.title] is Patch)
                    ? _patchMap[Todo$.title].applyTo(this.title)
                    : _patchMap[Todo$.title])
                as String
          : this.title,
      description: _patchMap.containsKey(Todo$.description)
          ? ((_patchMap[Todo$.description] is Function)
                    ? _patchMap[Todo$.description](this.description)
                    : (_patchMap[Todo$.description] is Patch)
                    ? _patchMap[Todo$.description].applyTo(this.description)
                    : _patchMap[Todo$.description])
                as String
          : this.description,
      isCompleted: _patchMap.containsKey(Todo$.isCompleted)
          ? ((_patchMap[Todo$.isCompleted] is Function)
                    ? _patchMap[Todo$.isCompleted](this.isCompleted)
                    : (_patchMap[Todo$.isCompleted] is Patch)
                    ? _patchMap[Todo$.isCompleted].applyTo(this.isCompleted)
                    : _patchMap[Todo$.isCompleted])
                as bool
          : this.isCompleted,
      priority: _patchMap.containsKey(Todo$.priority)
          ? ((_patchMap[Todo$.priority] is Function)
                    ? _patchMap[Todo$.priority](this.priority)
                    : (_patchMap[Todo$.priority] is Patch)
                    ? _patchMap[Todo$.priority].applyTo(this.priority)
                    : _patchMap[Todo$.priority])
                as TodoPriority
          : this.priority,
      tags: _patchMap.containsKey(Todo$.tags)
          ? ((_patchMap[Todo$.tags] is Function)
                    ? _patchMap[Todo$.tags](this.tags)
                    : (_patchMap[Todo$.tags] is Patch)
                    ? _patchMap[Todo$.tags].applyTo(this.tags)
                    : _patchMap[Todo$.tags])
                as List<String>
          : this.tags,
      createdAt: _patchMap.containsKey(Todo$.createdAt)
          ? ((_patchMap[Todo$.createdAt] is Function)
                    ? _patchMap[Todo$.createdAt](this.createdAt)
                    : (_patchMap[Todo$.createdAt] is Patch)
                    ? _patchMap[Todo$.createdAt].applyTo(this.createdAt)
                    : _patchMap[Todo$.createdAt])
                as DateTime
          : this.createdAt,
      completedAt: _patchMap.containsKey(Todo$.completedAt)
          ? ((_patchMap[Todo$.completedAt] is Function)
                    ? _patchMap[Todo$.completedAt](this.completedAt)
                    : (_patchMap[Todo$.completedAt] is Patch)
                    ? _patchMap[Todo$.completedAt].applyTo(this.completedAt)
                    : _patchMap[Todo$.completedAt])
                as DateTime
          : this.completedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Todo &&
        id == other.id &&
        title == other.title &&
        description == other.description &&
        isCompleted == other.isCompleted &&
        priority == other.priority &&
        tags == other.tags &&
        createdAt == other.createdAt &&
        completedAt == other.completedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.title,
      this.description,
      this.isCompleted,
      this.priority,
      this.tags,
      this.createdAt,
      this.completedAt,
    );
  }

  @override
  String toString() {
    return 'Todo(' +
        'id: ${id}' +
        ', ' +
        'title: ${title}' +
        ', ' +
        'description: ${description}' +
        ', ' +
        'isCompleted: ${isCompleted}' +
        ', ' +
        'priority: ${priority}' +
        ', ' +
        'tags: ${tags}' +
        ', ' +
        'createdAt: ${createdAt}' +
        ', ' +
        'completedAt: ${completedAt})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$TodoToJson(this);
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

extension TodoPropertyHelpers on Todo {
  bool get hasTitle {
    return this.title.isNotEmpty;
  }

  bool get noTitle {
    return this.title.isEmpty;
  }

  bool get hasDescription {
    return this.description.isNotEmpty;
  }

  bool get noDescription {
    return this.description.isEmpty;
  }

  bool get isPriorityLow {
    return this.priority == TodoPriority.low;
  }

  bool get isPriorityMedium {
    return this.priority == TodoPriority.medium;
  }

  bool get isPriorityHigh {
    return this.priority == TodoPriority.high;
  }

  bool get hasTags {
    return this.tags.isNotEmpty;
  }

  bool get noTags {
    return this.tags.isEmpty;
  }
}

extension TodoSerialization on Todo {
  Map<String, dynamic> toJson() {
    return _$TodoToJson(this);
  }
}

enum Todo$ {
  id,
  title,
  description,
  isCompleted,
  priority,
  tags,
  createdAt,
  completedAt,
}

class TodoPatch extends PatchBase<Todo, Todo$> {
  Todo applyTo(Todo entity) {
    return entity.patchWithTodo(this);
  }

  TodoPatch withId(int? value) {
    patchMap[Todo$.id] = value;
    return this;
  }

  TodoPatch withTitle(String? value) {
    patchMap[Todo$.title] = value;
    return this;
  }

  TodoPatch withDescription(String? value) {
    patchMap[Todo$.description] = value;
    return this;
  }

  TodoPatch withIsCompleted(bool? value) {
    patchMap[Todo$.isCompleted] = value;
    return this;
  }

  TodoPatch withPriority(TodoPriority? value) {
    patchMap[Todo$.priority] = value;
    return this;
  }

  TodoPatch withTags(List<String>? value) {
    patchMap[Todo$.tags] = value;
    return this;
  }

  TodoPatch withCreatedAt(DateTime? value) {
    patchMap[Todo$.createdAt] = value;
    return this;
  }

  TodoPatch withCompletedAt(DateTime? value) {
    patchMap[Todo$.completedAt] = value;
    return this;
  }
}

/// Field descriptors for [Todo] query construction
abstract final class TodoFields {
  static const id = Field<Todo, int>('id', _$id);

  static const title = Field<Todo, String>('title', _$title);

  static const description = Field<Todo, String>('description', _$description);

  static const isCompleted = Field<Todo, bool>('isCompleted', _$isCompleted);

  static const priority = Field<Todo, TodoPriority>('priority', _$priority);

  static const tags = Field<Todo, List<String>>('tags', _$tags);

  static const createdAt = Field<Todo, DateTime>('createdAt', _$createdAt);

  static const completedAt = Field<Todo, DateTime>(
    'completedAt',
    _$completedAt,
  );

  static int _$id(Todo e) {
    return e.id;
  }

  static String _$title(Todo e) {
    return e.title;
  }

  static String _$description(Todo e) {
    return e.description;
  }

  static bool _$isCompleted(Todo e) {
    return e.isCompleted;
  }

  static TodoPriority _$priority(Todo e) {
    return e.priority;
  }

  static List<String> _$tags(Todo e) {
    return e.tags;
  }

  static DateTime _$createdAt(Todo e) {
    return e.createdAt;
  }

  static DateTime _$completedAt(Todo e) {
    return e.completedAt;
  }
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

    if (description != other.description) {
      diff['description'] = () => other.description;
    }

    if (isCompleted != other.isCompleted) {
      diff['isCompleted'] = () => other.isCompleted;
    }

    if (priority != other.priority) {
      diff['priority'] = () => other.priority;
    }

    if (tags != other.tags) {
      diff['tags'] = () => other.tags;
    }

    if (createdAt != other.createdAt) {
      diff['createdAt'] = () => other.createdAt;
    }

    if (completedAt != other.completedAt) {
      diff['completedAt'] = () => other.completedAt;
    }
    return diff;
  }
}
