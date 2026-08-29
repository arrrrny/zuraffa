// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'note.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class Note {
  Note({required String this.id, required String this.body});

  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);

  final String id;

  final String body;

  Note copyWith({String? id, String? body}) {
    return Note(id: id ?? this.id, body: body ?? this.body);
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  Note copyWithField<T>(Field<Note, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'body':
        return copyWith(body: value as String);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'Note has no settable field with this name',
        );
    }
  }

  Note copyWithNote({String? id, String? body}) {
    return copyWith(id: id, body: body);
  }

  Note patchWithNote([NotePatch? patchInput]) {
    final _patcher = patchInput ?? NotePatch();
    final _patchMap = _patcher.patchMap;
    return Note(
      id: _patchMap.containsKey(Note$.id)
          ? ((_patchMap[Note$.id] is Function)
                    ? _patchMap[Note$.id](this.id)
                    : (_patchMap[Note$.id] is Patch)
                    ? _patchMap[Note$.id].applyTo(this.id)
                    : _patchMap[Note$.id])
                as String
          : this.id,
      body: _patchMap.containsKey(Note$.body)
          ? ((_patchMap[Note$.body] is Function)
                    ? _patchMap[Note$.body](this.body)
                    : (_patchMap[Note$.body] is Patch)
                    ? _patchMap[Note$.body].applyTo(this.body)
                    : _patchMap[Note$.body])
                as String
          : this.body,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Note && id == other.id && body == other.body;
  }

  @override
  int get hashCode {
    return Object.hash(this.id, this.body);
  }

  @override
  String toString() {
    return 'Note(' + 'id: ${id}' + ', ' + 'body: ${body})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$NoteToJson(this);
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

extension NotePropertyHelpers on Note {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasBody {
    return this.body.isNotEmpty;
  }

  bool get noBody {
    return this.body.isEmpty;
  }
}

extension NoteSerialization on Note {
  Map<String, dynamic> toJson() {
    return _$NoteToJson(this);
  }
}

enum Note$ { id, body }

class NotePatch extends PatchBase<Note, Note$> {
  Note applyTo(Note entity) {
    return entity.patchWithNote(this);
  }

  NotePatch withId(String? value) {
    patchMap[Note$.id] = value;
    return this;
  }

  NotePatch withBody(String? value) {
    patchMap[Note$.body] = value;
    return this;
  }
}

/// Field descriptors for [Note] query construction
abstract final class NoteFields {
  static const id = Field<Note, String>('id', _$id);

  static const body = Field<Note, String>('body', _$body);

  static String _$id(Note e) {
    return e.id;
  }

  static String _$body(Note e) {
    return e.body;
  }
}

extension NoteCompareE on Note {
  Map<String, dynamic> compareToNote(Note other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (body != other.body) {
      diff['body'] = () => other.body;
    }
    return diff;
  }
}
