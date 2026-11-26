// dart format off
part of '../../../../../src/domain/entities/todo/todo.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class Todo implements ZorphyEntityBase<String> {
  const Todo.fromTrusted({
    required this.id,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.priority,
    required this.tags,
    required this.createdAt,
    required this.completedAt,
  });

  final String id;

  final String title;

  final String description;

  final bool isCompleted;

  final int priority;

  final List<String> tags;

  final DateTime createdAt;

  final DateTime completedAt;

  static const TodoLenses lenses = TodoLenses();

  static const ZorphyEntityDescriptor<Todo> descriptor = _TodoDescriptor._();

  Todo copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    int? priority,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return Todo.fromTrusted(
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Todo &&
        this.id == other.id &&
        this.title == other.title &&
        this.description == other.description &&
        this.isCompleted == other.isCompleted &&
        this.priority == other.priority &&
        this.tags == other.tags &&
        this.createdAt == other.createdAt &&
        this.completedAt == other.completedAt;
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    description,
    isCompleted,
    priority,
    tags,
    createdAt,
    completedAt,
  ]);

  @override
  String toString() =>
      'Todo(id: $id, title: $title, description: $description, isCompleted: $isCompleted, priority: $priority, tags: $tags, createdAt: $createdAt, completedAt: $completedAt)';

  String get principalKey => id;

  static ZorphyBoundaryResult<Todo> fromWire(Map<String, Object?> raw) {
    final violations = <FieldViolation>[];
    final Object? raw_id = raw['id'];
    String? _id;
    _id = _boundaryAs<String>(raw_id, '/id', violations);
    final Object? raw_title = raw['title'];
    String? _title;
    _title = _boundaryAs<String>(raw_title, '/title', violations);
    final Object? raw_description = raw['description'];
    String? _description;
    _description = _boundaryAs<String>(
      raw_description,
      '/description',
      violations,
    );
    final Object? raw_isCompleted = raw['isCompleted'];
    bool? _isCompleted;
    _isCompleted = _boundaryAs<bool>(
      raw_isCompleted,
      '/isCompleted',
      violations,
    );
    final Object? raw_priority = raw['priority'];
    int? _priority;
    _priority = _boundaryAs<int>(raw_priority, '/priority', violations);
    final Object? raw_tags = raw['tags'];
    List<String>? _tags;
    final list_tags = _boundaryList(raw_tags, '/tags', violations);
    if (list_tags != null) {
      final decoded_tags = <String>[];
      for (var i = 0; i < list_tags.length; i++) {
        final path_tags = '/tags' + '[$i]';
        final element_tags = _boundaryAs<String>(
          list_tags[i],
          path_tags,
          violations,
        );
        if (element_tags != null) {
          decoded_tags.add(element_tags);
        }
      }
      _tags = decoded_tags;
    }
    final Object? raw_createdAt = raw['createdAt'];
    DateTime? _createdAt;
    _createdAt = _boundaryDateTime(raw_createdAt, '/createdAt', violations);
    final Object? raw_completedAt = raw['completedAt'];
    DateTime? _completedAt;
    _completedAt = _boundaryDateTime(
      raw_completedAt,
      '/completedAt',
      violations,
    );
    if (violations.isNotEmpty) {
      return BoundaryErr<Todo>(targetType: 'Todo', violations: violations);
    }
    return BoundaryOk<Todo>(
      Todo.fromTrusted(
        id: _id!,
        title: _title!,
        description: _description!,
        isCompleted: _isCompleted!,
        priority: _priority!,
        tags: _tags!,
        createdAt: _createdAt!,
        completedAt: _completedAt!,
      ),
    );
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{};
    map['id'] = this.id;
    map['title'] = this.title;
    map['description'] = this.description;
    map['isCompleted'] = this.isCompleted;
    map['priority'] = this.priority;
    map['tags'] = this.tags;
    map['createdAt'] = this.createdAt.toIso8601String();
    map['completedAt'] = this.completedAt.toIso8601String();
    return map;
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [Todo].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<Todo, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      '/id' => ZorphyLens<Todo, Object?>(
        path: '/id',
        get: (root) => root.id,
        set: (root, value) => root.copyWith(id: value as String),
      ),
      '/title' => ZorphyLens<Todo, Object?>(
        path: '/title',
        get: (root) => root.title,
        set: (root, value) => root.copyWith(title: value as String),
      ),
      '/description' => ZorphyLens<Todo, Object?>(
        path: '/description',
        get: (root) => root.description,
        set: (root, value) => root.copyWith(description: value as String),
      ),
      '/isCompleted' => ZorphyLens<Todo, Object?>(
        path: '/isCompleted',
        get: (root) => root.isCompleted,
        set: (root, value) => root.copyWith(isCompleted: value as bool),
      ),
      '/priority' => ZorphyLens<Todo, Object?>(
        path: '/priority',
        get: (root) => root.priority,
        set: (root, value) => root.copyWith(priority: value as int),
      ),
      '/tags' => ZorphyLens<Todo, Object?>(
        path: '/tags',
        get: (root) => root.tags,
        set: (root, value) => root.copyWith(tags: value as List<String>),
      ),
      '/createdAt' => ZorphyLens<Todo, Object?>(
        path: '/createdAt',
        get: (root) => root.createdAt,
        set: (root, value) => root.copyWith(createdAt: value as DateTime),
      ),
      '/completedAt' => ZorphyLens<Todo, Object?>(
        path: '/completedAt',
        get: (root) => root.completedAt,
        set: (root, value) => root.copyWith(completedAt: value as DateTime),
      ),
      _ => null,
    };
  }
}

final class TodoPatch implements ZorphyPatch<Todo> {
  TodoPatch({
    PatchValue<String> id = const PatchValue.unchanged(),
    PatchValue<String> title = const PatchValue.unchanged(),
    PatchValue<String> description = const PatchValue.unchanged(),
    PatchValue<bool> isCompleted = const PatchValue.unchanged(),
    PatchValue<int> priority = const PatchValue.unchanged(),
    PatchValue<List<String>> tags = const PatchValue.unchanged(),
    PatchValue<DateTime> createdAt = const PatchValue.unchanged(),
    PatchValue<DateTime> completedAt = const PatchValue.unchanged(),
  }) : id = id,
       title = title,
       description = description,
       isCompleted = isCompleted,
       priority = priority,
       tags = tags.isUnchanged
           ? tags
           : PatchValue.set(List<String>.unmodifiable(tags.valueOrNull!)),
       createdAt = createdAt,
       completedAt = completedAt;

  final PatchValue<String> id;

  final PatchValue<String> title;

  final PatchValue<String> description;

  final PatchValue<bool> isCompleted;

  final PatchValue<int> priority;

  final PatchValue<List<String>> tags;

  final PatchValue<DateTime> createdAt;

  final PatchValue<DateTime> completedAt;

  TodoPatch withId(String value) {
    return TodoPatch(
      id: PatchValue.set(value),
      title: this.title,
      description: this.description,
      isCompleted: this.isCompleted,
      priority: this.priority,
      tags: this.tags,
      createdAt: this.createdAt,
      completedAt: this.completedAt,
    );
  }

  TodoPatch withTitle(String value) {
    return TodoPatch(
      id: this.id,
      title: PatchValue.set(value),
      description: this.description,
      isCompleted: this.isCompleted,
      priority: this.priority,
      tags: this.tags,
      createdAt: this.createdAt,
      completedAt: this.completedAt,
    );
  }

  TodoPatch withDescription(String value) {
    return TodoPatch(
      id: this.id,
      title: this.title,
      description: PatchValue.set(value),
      isCompleted: this.isCompleted,
      priority: this.priority,
      tags: this.tags,
      createdAt: this.createdAt,
      completedAt: this.completedAt,
    );
  }

  TodoPatch withIsCompleted(bool value) {
    return TodoPatch(
      id: this.id,
      title: this.title,
      description: this.description,
      isCompleted: PatchValue.set(value),
      priority: this.priority,
      tags: this.tags,
      createdAt: this.createdAt,
      completedAt: this.completedAt,
    );
  }

  TodoPatch withPriority(int value) {
    return TodoPatch(
      id: this.id,
      title: this.title,
      description: this.description,
      isCompleted: this.isCompleted,
      priority: PatchValue.set(value),
      tags: this.tags,
      createdAt: this.createdAt,
      completedAt: this.completedAt,
    );
  }

  TodoPatch withTags(List<String> value) {
    return TodoPatch(
      id: this.id,
      title: this.title,
      description: this.description,
      isCompleted: this.isCompleted,
      priority: this.priority,
      tags: PatchValue.set(value),
      createdAt: this.createdAt,
      completedAt: this.completedAt,
    );
  }

  TodoPatch withCreatedAt(DateTime value) {
    return TodoPatch(
      id: this.id,
      title: this.title,
      description: this.description,
      isCompleted: this.isCompleted,
      priority: this.priority,
      tags: this.tags,
      createdAt: PatchValue.set(value),
      completedAt: this.completedAt,
    );
  }

  TodoPatch withCompletedAt(DateTime value) {
    return TodoPatch(
      id: this.id,
      title: this.title,
      description: this.description,
      isCompleted: this.isCompleted,
      priority: this.priority,
      tags: this.tags,
      createdAt: this.createdAt,
      completedAt: PatchValue.set(value),
    );
  }

  @override
  bool get isEmpty {
    return id.isUnchanged &&
        title.isUnchanged &&
        description.isUnchanged &&
        isCompleted.isUnchanged &&
        priority.isUnchanged &&
        tags.isUnchanged &&
        createdAt.isUnchanged &&
        completedAt.isUnchanged;
  }

  @override
  bool get isNotEmpty {
    return !isEmpty;
  }

  @override
  Todo apply(covariant Todo target) {
    if (isEmpty) return target;
    return target.copyWith(
      id: this.id.isUnchanged ? target.id : this.id.valueOrNull,
      title: this.title.isUnchanged ? target.title : this.title.valueOrNull,
      description: this.description.isUnchanged
          ? target.description
          : this.description.valueOrNull,
      isCompleted: this.isCompleted.isUnchanged
          ? target.isCompleted
          : this.isCompleted.valueOrNull,
      priority: this.priority.isUnchanged
          ? target.priority
          : this.priority.valueOrNull,
      tags: this.tags.isUnchanged ? target.tags : this.tags.valueOrNull,
      createdAt: this.createdAt.isUnchanged
          ? target.createdAt
          : this.createdAt.valueOrNull,
      completedAt: this.completedAt.isUnchanged
          ? target.completedAt
          : this.completedAt.valueOrNull,
    );
  }

  @override
  TodoPatch compose(ZorphyPatch<Todo> next) {
    if (next.isEmpty) return this;
    if (next is! TodoPatch) {
      throw ArgumentError.value(
        next,
        'next',
        'TodoPatch cannot compose ${next.runtimeType}',
      );
    }
    if (isEmpty) return next;
    return TodoPatch(
      id: next.id.isUnchanged ? this.id : next.id,
      title: next.title.isUnchanged ? this.title : next.title,
      description: next.description.isUnchanged
          ? this.description
          : next.description,
      isCompleted: next.isCompleted.isUnchanged
          ? this.isCompleted
          : next.isCompleted,
      priority: next.priority.isUnchanged ? this.priority : next.priority,
      tags: next.tags.isUnchanged ? this.tags : next.tags,
      createdAt: next.createdAt.isUnchanged ? this.createdAt : next.createdAt,
      completedAt: next.completedAt.isUnchanged
          ? this.completedAt
          : next.completedAt,
    );
  }

  @override
  TodoPatch invert(Todo before) {
    return TodoPatch(
      id: this.id.isUnchanged
          ? const PatchValue.unchanged()
          : PatchValue.set(before.id),
      title: this.title.isUnchanged
          ? const PatchValue.unchanged()
          : PatchValue.set(before.title),
      description: this.description.isUnchanged
          ? const PatchValue.unchanged()
          : PatchValue.set(before.description),
      isCompleted: this.isCompleted.isUnchanged
          ? const PatchValue.unchanged()
          : PatchValue.set(before.isCompleted),
      priority: this.priority.isUnchanged
          ? const PatchValue.unchanged()
          : PatchValue.set(before.priority),
      tags: this.tags.isUnchanged
          ? const PatchValue.unchanged()
          : PatchValue.set(before.tags),
      createdAt: this.createdAt.isUnchanged
          ? const PatchValue.unchanged()
          : PatchValue.set(before.createdAt),
      completedAt: this.completedAt.isUnchanged
          ? const PatchValue.unchanged()
          : PatchValue.set(before.completedAt),
    );
  }

  @override
  Map<String, Object?> toWire() {
    final wire = <String, Object?>{};
    if (this.id.isSet) wire['id'] = this.id.valueOrNull;
    if (this.title.isSet) wire['title'] = this.title.valueOrNull;
    if (this.description.isSet)
      wire['description'] = this.description.valueOrNull;
    if (this.isCompleted.isSet)
      wire['isCompleted'] = this.isCompleted.valueOrNull;
    if (this.priority.isSet) wire['priority'] = this.priority.valueOrNull;
    if (this.tags.isSet) wire['tags'] = this.tags.valueOrNull;
    if (this.createdAt.isSet) wire['createdAt'] = this.createdAt.valueOrNull;
    if (this.completedAt.isSet)
      wire['completedAt'] = this.completedAt.valueOrNull;
    return wire;
  }

  Map<String, Object?> toEnvelope({Object? principalKey}) {
    return <String, Object?>{
      'entityType': 'Todo',
      'patchKind': 'Todo',
      'principalKey': principalKey,
      'ops': toWire(),
    };
  }

  static TodoPatch diff(Todo previous, Todo next) {
    if (identical(previous, next)) return TodoPatch();
    var changes = TodoPatch();
    if (previous.id != next.id) changes = changes.withId(next.id);
    if (previous.title != next.title) changes = changes.withTitle(next.title);
    if (previous.description != next.description)
      changes = changes.withDescription(next.description);
    if (previous.isCompleted != next.isCompleted)
      changes = changes.withIsCompleted(next.isCompleted);
    if (previous.priority != next.priority)
      changes = changes.withPriority(next.priority);
    if (previous.tags != next.tags) changes = changes.withTags(next.tags);
    if (previous.createdAt != next.createdAt)
      changes = changes.withCreatedAt(next.createdAt);
    if (previous.completedAt != next.completedAt)
      changes = changes.withCompletedAt(next.completedAt);
    return changes;
  }

  static ZorphyBoundaryResult<TodoPatch> fromWire(Map<String, Object?> raw) {
    final violations = <FieldViolation>[];
    final ops = ZorphyPatchWire.opsOf(raw, '', violations);
    PatchValue<String>? idValue;
    if (ops != null && ops.containsKey('id')) {
      final Object? rawValue = ZorphyPatchWire.fieldValue(
        ops['id'],
        '/id',
        violations,
      );
      idValue = (() {
        final idDecoded = ZorphyPatchWire.as<String>(
          rawValue,
          '/id',
          violations,
        );
        return idDecoded == null ? null : PatchValue<String>.set(idDecoded);
      })();
    }
    PatchValue<String>? titleValue;
    if (ops != null && ops.containsKey('title')) {
      final Object? rawValue = ZorphyPatchWire.fieldValue(
        ops['title'],
        '/title',
        violations,
      );
      titleValue = (() {
        final titleDecoded = ZorphyPatchWire.as<String>(
          rawValue,
          '/title',
          violations,
        );
        return titleDecoded == null
            ? null
            : PatchValue<String>.set(titleDecoded);
      })();
    }
    PatchValue<String>? descriptionValue;
    if (ops != null && ops.containsKey('description')) {
      final Object? rawValue = ZorphyPatchWire.fieldValue(
        ops['description'],
        '/description',
        violations,
      );
      descriptionValue = (() {
        final descriptionDecoded = ZorphyPatchWire.as<String>(
          rawValue,
          '/description',
          violations,
        );
        return descriptionDecoded == null
            ? null
            : PatchValue<String>.set(descriptionDecoded);
      })();
    }
    PatchValue<bool>? isCompletedValue;
    if (ops != null && ops.containsKey('isCompleted')) {
      final Object? rawValue = ZorphyPatchWire.fieldValue(
        ops['isCompleted'],
        '/isCompleted',
        violations,
      );
      isCompletedValue = (() {
        final isCompletedDecoded = ZorphyPatchWire.as<bool>(
          rawValue,
          '/isCompleted',
          violations,
        );
        return isCompletedDecoded == null
            ? null
            : PatchValue<bool>.set(isCompletedDecoded);
      })();
    }
    PatchValue<int>? priorityValue;
    if (ops != null && ops.containsKey('priority')) {
      final Object? rawValue = ZorphyPatchWire.fieldValue(
        ops['priority'],
        '/priority',
        violations,
      );
      priorityValue = (() {
        final priorityDecoded = ZorphyPatchWire.as<int>(
          rawValue,
          '/priority',
          violations,
        );
        return priorityDecoded == null
            ? null
            : PatchValue<int>.set(priorityDecoded);
      })();
    }
    PatchValue<List<String>>? tagsValue;
    if (ops != null && ops.containsKey('tags')) {
      final Object? rawValue = ZorphyPatchWire.fieldValue(
        ops['tags'],
        '/tags',
        violations,
      );
      tagsValue = (() {
        final values = _boundaryList(rawValue, '/tags', violations);
        if (values == null) return null;
        final decoded = <String>[];
        for (var i = 0; i < values.length; i++) {
          final element = _boundaryAs<String>(
            values[i],
            '/tags' + '[$i]',
            violations,
          );
          if (element != null) decoded.add(element);
        }
        return PatchValue<List<String>>.set(decoded);
      })();
    }
    PatchValue<DateTime>? createdAtValue;
    if (ops != null && ops.containsKey('createdAt')) {
      final Object? rawValue = ZorphyPatchWire.fieldValue(
        ops['createdAt'],
        '/createdAt',
        violations,
      );
      createdAtValue = (() {
        final createdAtDecoded = ZorphyPatchWire.asDateTime(
          rawValue,
          '/createdAt',
          violations,
        );
        return createdAtDecoded == null
            ? null
            : PatchValue<DateTime>.set(createdAtDecoded);
      })();
    }
    PatchValue<DateTime>? completedAtValue;
    if (ops != null && ops.containsKey('completedAt')) {
      final Object? rawValue = ZorphyPatchWire.fieldValue(
        ops['completedAt'],
        '/completedAt',
        violations,
      );
      completedAtValue = (() {
        final completedAtDecoded = ZorphyPatchWire.asDateTime(
          rawValue,
          '/completedAt',
          violations,
        );
        return completedAtDecoded == null
            ? null
            : PatchValue<DateTime>.set(completedAtDecoded);
      })();
    }
    if (violations.isNotEmpty) {
      return BoundaryErr<TodoPatch>(
        targetType: 'TodoPatch',
        violations: violations,
      );
    }
    return BoundaryOk<TodoPatch>(
      TodoPatch(
        id: idValue ?? const PatchValue<String>.unchanged(),
        title: titleValue ?? const PatchValue<String>.unchanged(),
        description: descriptionValue ?? const PatchValue<String>.unchanged(),
        isCompleted: isCompletedValue ?? const PatchValue<bool>.unchanged(),
        priority: priorityValue ?? const PatchValue<int>.unchanged(),
        tags: tagsValue ?? const PatchValue<List<String>>.unchanged(),
        createdAt: createdAtValue ?? const PatchValue<DateTime>.unchanged(),
        completedAt: completedAtValue ?? const PatchValue<DateTime>.unchanged(),
      ),
    );
  }
}

class TodoMockData {
  TodoMockData._();

  static Todo single({int seed = 0}) {
    return Todo.fromTrusted(
      id: 'id-${seed}',
      title: 'title-${seed}',
      description: 'description-${seed}',
      isCompleted: (seed + 145) % 2 == 0,
      priority: seed % 97 + 548,
      tags: ['tags-${seed}'],
      createdAt: DateTime.utc(2026, 1, 1).add(Duration(hours: seed + 299)),
      completedAt: DateTime.utc(2026, 1, 1).add(Duration(hours: seed + 638)),
    );
  }

  static List<Todo> list({int count = 10}) {
    return List<Todo>.generate(count, (index) => single(seed: index));
  }

  static TodoPatch samplePatch() {
    var patch = TodoPatch();
    patch = patch.withId('id-${0}');
    patch = patch.withTitle('title-${0}');
    patch = patch.withDescription('description-${0}');
    patch = patch.withIsCompleted((0 + 145) % 2 == 0);
    patch = patch.withPriority(0 % 97 + 548);
    patch = patch.withTags(['tags-${0}']);
    patch = patch.withCreatedAt(
      DateTime.utc(2026, 1, 1).add(Duration(hours: 0 + 299)),
    );
    patch = patch.withCompletedAt(
      DateTime.utc(2026, 1, 1).add(Duration(hours: 0 + 638)),
    );
    return patch;
  }
}

class TodoWireFixtures {
  TodoWireFixtures._();

  static Map<String, Object?> validMap({int seed = 0}) {
    return TodoMockData.single(seed: seed).toWire();
  }

  static List<Map<String, Object?>> corruptMaps() {
    final base = validMap();
    final maps = <Map<String, Object?>>[];
    maps.add(Map<String, Object?>.of(base)..remove('id'));
    maps.add(Map<String, Object?>.of(base)..['id'] = 12345);
    maps.add(Map<String, Object?>.of(base)..remove('title'));
    maps.add(Map<String, Object?>.of(base)..['title'] = 12345);
    maps.add(Map<String, Object?>.of(base)..remove('description'));
    maps.add(Map<String, Object?>.of(base)..['description'] = 12345);
    maps.add(Map<String, Object?>.of(base)..remove('isCompleted'));
    maps.add(Map<String, Object?>.of(base)..['isCompleted'] = 'not-a-bool');
    maps.add(Map<String, Object?>.of(base)..remove('priority'));
    maps.add(Map<String, Object?>.of(base)..['priority'] = 'not-an-int');
    maps.add(Map<String, Object?>.of(base)..remove('tags'));
    maps.add(Map<String, Object?>.of(base)..['tags'] = 'not-a-list');
    maps.add(Map<String, Object?>.of(base)..remove('createdAt'));
    maps.add(Map<String, Object?>.of(base)..['createdAt'] = 'not-a-datetime');
    maps.add(Map<String, Object?>.of(base)..remove('completedAt'));
    maps.add(Map<String, Object?>.of(base)..['completedAt'] = 'not-a-datetime');
    return maps;
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

List<Object?>? _boundaryList(
  Object? value,
  String path,
  List<FieldViolation> violations,
) {
  if (value is List<Object?>) return value;
  if (value is List) return List<Object?>.of(value);
  violations.add(
    FieldViolation(
      path: path,
      expected: 'List<Object?>',
      actual: _boundaryDescribe(value),
    ),
  );
  return null;
}

DateTime? _boundaryDateTime(
  Object? value,
  String path,
  List<FieldViolation> violations,
) {
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  violations.add(
    FieldViolation(
      path: path,
      expected: 'DateTime (ISO-8601 String)',
      actual: _boundaryDescribe(value),
    ),
  );
  return null;
}

/// Typed lenses over [Todo] — one per writable field.
///
/// Compose with `then` to reach a nested value:
/// `Todo.lenses.<field>.then(<Nested>.lenses.<leaf>)`.
final class TodoLenses {
  const TodoLenses();

  ZorphyLens<Todo, String> get id =>
      const ZorphyLens<Todo, String>(path: '/id', get: _getId, set: _setId);

  static String _getId(Todo root) => root.id;

  static Todo _setId(Todo root, String value) => root.copyWith(id: value);

  ZorphyLens<Todo, String> get title => const ZorphyLens<Todo, String>(
    path: '/title',
    get: _getTitle,
    set: _setTitle,
  );

  static String _getTitle(Todo root) => root.title;

  static Todo _setTitle(Todo root, String value) => root.copyWith(title: value);

  ZorphyLens<Todo, String> get description => const ZorphyLens<Todo, String>(
    path: '/description',
    get: _getDescription,
    set: _setDescription,
  );

  static String _getDescription(Todo root) => root.description;

  static Todo _setDescription(Todo root, String value) =>
      root.copyWith(description: value);

  ZorphyLens<Todo, bool> get isCompleted => const ZorphyLens<Todo, bool>(
    path: '/isCompleted',
    get: _getIsCompleted,
    set: _setIsCompleted,
  );

  static bool _getIsCompleted(Todo root) => root.isCompleted;

  static Todo _setIsCompleted(Todo root, bool value) =>
      root.copyWith(isCompleted: value);

  ZorphyLens<Todo, int> get priority => const ZorphyLens<Todo, int>(
    path: '/priority',
    get: _getPriority,
    set: _setPriority,
  );

  static int _getPriority(Todo root) => root.priority;

  static Todo _setPriority(Todo root, int value) =>
      root.copyWith(priority: value);

  ZorphyLens<Todo, List<String>> get tags =>
      const ZorphyLens<Todo, List<String>>(
        path: '/tags',
        get: _getTags,
        set: _setTags,
      );

  static List<String> _getTags(Todo root) => root.tags;

  static Todo _setTags(Todo root, List<String> value) =>
      root.copyWith(tags: value);

  ZorphyLens<Todo, DateTime> get createdAt => const ZorphyLens<Todo, DateTime>(
    path: '/createdAt',
    get: _getCreatedAt,
    set: _setCreatedAt,
  );

  static DateTime _getCreatedAt(Todo root) => root.createdAt;

  static Todo _setCreatedAt(Todo root, DateTime value) =>
      root.copyWith(createdAt: value);

  ZorphyLens<Todo, DateTime> get completedAt =>
      const ZorphyLens<Todo, DateTime>(
        path: '/completedAt',
        get: _getCompletedAt,
        set: _setCompletedAt,
      );

  static DateTime _getCompletedAt(Todo root) => root.completedAt;

  static Todo _setCompletedAt(Todo root, DateTime value) =>
      root.copyWith(completedAt: value);
}

/// The reflection-free descriptor for [Todo] (issue #251).
final class _TodoDescriptor implements ZorphyEntityDescriptor<Todo> {
  const _TodoDescriptor._();

  String get typeName {
    return 'Todo';
  }

  Field<Todo, Object?> get principalKeyField {
    return Field<Todo, Object?>('id', (entity) => entity.id);
  }

  List<Field<Todo, Object?>> get fields {
    return [
      Field<Todo, Object?>('id', (entity) => entity.id),
      Field<Todo, Object?>('title', (entity) => entity.title),
      Field<Todo, Object?>('description', (entity) => entity.description),
      Field<Todo, Object?>('isCompleted', (entity) => entity.isCompleted),
      Field<Todo, Object?>('priority', (entity) => entity.priority),
      Field<Todo, Object?>('tags', (entity) => entity.tags),
      Field<Todo, Object?>('createdAt', (entity) => entity.createdAt),
      Field<Todo, Object?>('completedAt', (entity) => entity.completedAt),
    ];
  }

  ZorphyPatch<Todo> diff(Todo previous, Todo next) {
    return TodoPatch.diff(previous, next);
  }

  Todo applyPatch(Todo entity, ZorphyPatch<Todo> patch) {
    return patch.apply(entity);
  }

  Map<String, Object?> toWire(Todo entity) {
    return entity.toWire();
  }

  ZorphyBoundaryResult<Todo> fromWire(Map<String, Object?> raw) {
    return Todo.fromWire(raw);
  }

  Object principalKeyOf(Todo entity) {
    return entity.id;
  }

  Field<Todo, Object?>? fieldByPath(String jsonPointer) {
    final name = jsonPointer.startsWith('/')
        ? jsonPointer.substring(1)
        : jsonPointer;
    for (final field in fields) {
      if (field.name == name) return field;
    }
    return null;
  }

  Set<String> conflictingPaths(ZorphyPatch<Todo> a, ZorphyPatch<Todo> b) {
    final mine = a.toWire().keys.toSet();
    final theirs = b.toWire().keys.toSet();
    return <String>{for (final key in mine.intersection(theirs)) '/$key'};
  }

  ZorphyPatch<Todo> composePatches(
    ZorphyPatch<Todo> base,
    ZorphyPatch<Todo> next,
  ) {
    return base.compose(next);
  }
}

