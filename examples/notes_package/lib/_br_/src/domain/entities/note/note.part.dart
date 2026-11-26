// dart format off
part of '../../../../../src/domain/entities/note/note.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class Note implements ZorphyEntityBase<String> {
  const Note.fromTrusted({required this.id, required this.body});

  final String id;

  final String body;

  static const NoteLenses lenses = NoteLenses();

  static const ZorphyEntityDescriptor<Note> descriptor = _NoteDescriptor._();

  Note copyWith({String? id, String? body}) {
    return Note.fromTrusted(id: id ?? this.id, body: body ?? this.body);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Note && this.id == other.id && this.body == other.body;
  }

  @override
  int get hashCode => Object.hashAll([id, body]);

  @override
  String toString() => 'Note(id: $id, body: $body)';

  String get principalKey => id;

  static ZorphyBoundaryResult<Note> fromWire(Map<String, Object?> raw) {
    final violations = <FieldViolation>[];
    final Object? raw_id = raw['id'];
    String? _id;
    _id = _boundaryAs<String>(raw_id, '/id', violations);
    final Object? raw_body = raw['body'];
    String? _body;
    _body = _boundaryAs<String>(raw_body, '/body', violations);
    if (violations.isNotEmpty) {
      return BoundaryErr<Note>(targetType: 'Note', violations: violations);
    }
    return BoundaryOk<Note>(Note.fromTrusted(id: _id!, body: _body!));
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{};
    map['id'] = this.id;
    map['body'] = this.body;
    return map;
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [Note].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<Note, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      '/id' => ZorphyLens<Note, Object?>(
        path: '/id',
        get: (root) => root.id,
        set: (root, value) => root.copyWith(id: value as String),
      ),
      '/body' => ZorphyLens<Note, Object?>(
        path: '/body',
        get: (root) => root.body,
        set: (root, value) => root.copyWith(body: value as String),
      ),
      _ => null,
    };
  }
}

final class NotePatch implements ZorphyPatch<Note> {
  NotePatch({
    PatchValue<String> id = const PatchValue.unchanged(),
    PatchValue<String> body = const PatchValue.unchanged(),
  }) : id = id,
       body = body;

  final PatchValue<String> id;

  final PatchValue<String> body;

  NotePatch withId(String value) {
    return NotePatch(id: PatchValue.set(value), body: this.body);
  }

  NotePatch withBody(String value) {
    return NotePatch(id: this.id, body: PatchValue.set(value));
  }

  @override
  bool get isEmpty {
    return id.isUnchanged && body.isUnchanged;
  }

  @override
  bool get isNotEmpty {
    return !isEmpty;
  }

  @override
  Note apply(covariant Note target) {
    if (isEmpty) return target;
    return target.copyWith(
      id: this.id.isUnchanged ? target.id : this.id.valueOrNull,
      body: this.body.isUnchanged ? target.body : this.body.valueOrNull,
    );
  }

  @override
  NotePatch compose(ZorphyPatch<Note> next) {
    if (next.isEmpty) return this;
    if (next is! NotePatch) {
      throw ArgumentError.value(
        next,
        'next',
        'NotePatch cannot compose ${next.runtimeType}',
      );
    }
    if (isEmpty) return next;
    return NotePatch(
      id: next.id.isUnchanged ? this.id : next.id,
      body: next.body.isUnchanged ? this.body : next.body,
    );
  }

  @override
  NotePatch invert(Note before) {
    return NotePatch(
      id: this.id.isUnchanged
          ? const PatchValue.unchanged()
          : PatchValue.set(before.id),
      body: this.body.isUnchanged
          ? const PatchValue.unchanged()
          : PatchValue.set(before.body),
    );
  }

  @override
  Map<String, Object?> toWire() {
    final wire = <String, Object?>{};
    if (this.id.isSet) wire['id'] = this.id.valueOrNull;
    if (this.body.isSet) wire['body'] = this.body.valueOrNull;
    return wire;
  }

  Map<String, Object?> toEnvelope({Object? principalKey}) {
    return <String, Object?>{
      'entityType': 'Note',
      'patchKind': 'Note',
      'principalKey': principalKey,
      'ops': toWire(),
    };
  }

  static NotePatch diff(Note previous, Note next) {
    if (identical(previous, next)) return NotePatch();
    var changes = NotePatch();
    if (previous.id != next.id) changes = changes.withId(next.id);
    if (previous.body != next.body) changes = changes.withBody(next.body);
    return changes;
  }

  static ZorphyBoundaryResult<NotePatch> fromWire(Map<String, Object?> raw) {
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
    PatchValue<String>? bodyValue;
    if (ops != null && ops.containsKey('body')) {
      final Object? rawValue = ZorphyPatchWire.fieldValue(
        ops['body'],
        '/body',
        violations,
      );
      bodyValue = (() {
        final bodyDecoded = ZorphyPatchWire.as<String>(
          rawValue,
          '/body',
          violations,
        );
        return bodyDecoded == null ? null : PatchValue<String>.set(bodyDecoded);
      })();
    }
    if (violations.isNotEmpty) {
      return BoundaryErr<NotePatch>(
        targetType: 'NotePatch',
        violations: violations,
      );
    }
    return BoundaryOk<NotePatch>(
      NotePatch(
        id: idValue ?? const PatchValue<String>.unchanged(),
        body: bodyValue ?? const PatchValue<String>.unchanged(),
      ),
    );
  }
}

class NoteMockData {
  NoteMockData._();

  static Note single({int seed = 0}) {
    return Note.fromTrusted(id: 'id-${seed}', body: 'body-${seed}');
  }

  static List<Note> list({int count = 10}) {
    return List<Note>.generate(count, (index) => single(seed: index));
  }

  static NotePatch samplePatch() {
    var patch = NotePatch();
    patch = patch.withId('id-${0}');
    patch = patch.withBody('body-${0}');
    return patch;
  }
}

class NoteWireFixtures {
  NoteWireFixtures._();

  static Map<String, Object?> validMap({int seed = 0}) {
    return NoteMockData.single(seed: seed).toWire();
  }

  static List<Map<String, Object?>> corruptMaps() {
    final base = validMap();
    final maps = <Map<String, Object?>>[];
    maps.add(Map<String, Object?>.of(base)..remove('id'));
    maps.add(Map<String, Object?>.of(base)..['id'] = 12345);
    maps.add(Map<String, Object?>.of(base)..remove('body'));
    maps.add(Map<String, Object?>.of(base)..['body'] = 12345);
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

/// Typed lenses over [Note] — one per writable field.
///
/// Compose with `then` to reach a nested value:
/// `Note.lenses.<field>.then(<Nested>.lenses.<leaf>)`.
final class NoteLenses {
  const NoteLenses();

  ZorphyLens<Note, String> get id =>
      const ZorphyLens<Note, String>(path: '/id', get: _getId, set: _setId);

  static String _getId(Note root) => root.id;

  static Note _setId(Note root, String value) => root.copyWith(id: value);

  ZorphyLens<Note, String> get body => const ZorphyLens<Note, String>(
    path: '/body',
    get: _getBody,
    set: _setBody,
  );

  static String _getBody(Note root) => root.body;

  static Note _setBody(Note root, String value) => root.copyWith(body: value);
}

/// The reflection-free descriptor for [Note] (issue #251).
final class _NoteDescriptor implements ZorphyEntityDescriptor<Note> {
  const _NoteDescriptor._();

  String get typeName {
    return 'Note';
  }

  Field<Note, Object?> get principalKeyField {
    return Field<Note, Object?>('id', (entity) => entity.id);
  }

  List<Field<Note, Object?>> get fields {
    return [
      Field<Note, Object?>('id', (entity) => entity.id),
      Field<Note, Object?>('body', (entity) => entity.body),
    ];
  }

  ZorphyPatch<Note> diff(Note previous, Note next) {
    return NotePatch.diff(previous, next);
  }

  Note applyPatch(Note entity, ZorphyPatch<Note> patch) {
    return patch.apply(entity);
  }

  Map<String, Object?> toWire(Note entity) {
    return entity.toWire();
  }

  ZorphyBoundaryResult<Note> fromWire(Map<String, Object?> raw) {
    return Note.fromWire(raw);
  }

  Object principalKeyOf(Note entity) {
    return entity.id;
  }

  Field<Note, Object?>? fieldByPath(String jsonPointer) {
    final name = jsonPointer.startsWith('/')
        ? jsonPointer.substring(1)
        : jsonPointer;
    for (final field in fields) {
      if (field.name == name) return field;
    }
    return null;
  }

  Set<String> conflictingPaths(ZorphyPatch<Note> a, ZorphyPatch<Note> b) {
    final mine = a.toWire().keys.toSet();
    final theirs = b.toWire().keys.toSet();
    return <String>{for (final key in mine.intersection(theirs)) '/$key'};
  }

  ZorphyPatch<Note> composePatches(
    ZorphyPatch<Note> base,
    ZorphyPatch<Note> next,
  ) {
    return base.compose(next);
  }
}

