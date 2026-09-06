// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'dynamic_form.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class DynamicForm {
  DynamicForm({
    String? id,
    required String this.code,
    required int this.version,
    required String this.name,
    String? this.description,
  }) : this.id = id ?? const Uuid().v4();

  factory DynamicForm.fromJson(Map<String, dynamic> json) =>
      _$DynamicFormFromJson(json);

  final String id;

  final String code;

  final int version;

  final String name;

  final String? description;

  DynamicForm copyWith({
    String? id,
    String? code,
    int? version,
    String? name,
    String? description,
  }) {
    return DynamicForm(
      id: id ?? this.id,
      code: code ?? this.code,
      version: version ?? this.version,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  DynamicForm copyWithField<T>(Field<DynamicForm, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'code':
        return copyWith(code: value as String);
      case 'version':
        return copyWith(version: value as int);
      case 'name':
        return copyWith(name: value as String);
      case 'description':
        return copyWith(description: value as String?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'DynamicForm has no settable field with this name',
        );
    }
  }

  DynamicForm copyWithDynamicForm({
    String? id,
    String? code,
    int? version,
    String? name,
    String? description,
  }) {
    return copyWith(
      id: id,
      code: code,
      version: version,
      name: name,
      description: description,
    );
  }

  DynamicForm patchWithDynamicForm([DynamicFormPatch? patchInput]) {
    final _patcher = patchInput ?? DynamicFormPatch();
    final _patchMap = _patcher.patchMap;
    return DynamicForm(
      id: _patchMap.containsKey(DynamicForm$.id)
          ? ((_patchMap[DynamicForm$.id] is Function)
                    ? _patchMap[DynamicForm$.id](this.id)
                    : (_patchMap[DynamicForm$.id] is Patch)
                    ? _patchMap[DynamicForm$.id].applyTo(this.id)
                    : _patchMap[DynamicForm$.id])
                as String
          : this.id,
      code: _patchMap.containsKey(DynamicForm$.code)
          ? ((_patchMap[DynamicForm$.code] is Function)
                    ? _patchMap[DynamicForm$.code](this.code)
                    : (_patchMap[DynamicForm$.code] is Patch)
                    ? _patchMap[DynamicForm$.code].applyTo(this.code)
                    : _patchMap[DynamicForm$.code])
                as String
          : this.code,
      version: _patchMap.containsKey(DynamicForm$.version)
          ? ((_patchMap[DynamicForm$.version] is Function)
                    ? _patchMap[DynamicForm$.version](this.version)
                    : (_patchMap[DynamicForm$.version] is Patch)
                    ? _patchMap[DynamicForm$.version].applyTo(this.version)
                    : _patchMap[DynamicForm$.version])
                as int
          : this.version,
      name: _patchMap.containsKey(DynamicForm$.name_)
          ? ((_patchMap[DynamicForm$.name_] is Function)
                    ? _patchMap[DynamicForm$.name_](this.name)
                    : (_patchMap[DynamicForm$.name_] is Patch)
                    ? _patchMap[DynamicForm$.name_].applyTo(this.name)
                    : _patchMap[DynamicForm$.name_])
                as String
          : this.name,
      description: _patchMap.containsKey(DynamicForm$.description)
          ? ((_patchMap[DynamicForm$.description] is Function)
                    ? _patchMap[DynamicForm$.description](this.description)
                    : (_patchMap[DynamicForm$.description] is Patch)
                    ? _patchMap[DynamicForm$.description].applyTo(
                        this.description,
                      )
                    : _patchMap[DynamicForm$.description])
                as String?
          : this.description,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DynamicForm &&
        id == other.id &&
        code == other.code &&
        version == other.version &&
        name == other.name &&
        description == other.description;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.code,
      this.version,
      this.name,
      this.description,
    );
  }

  @override
  String toString() {
    return 'DynamicForm(' +
        'id: ${id}' +
        ', ' +
        'code: ${code}' +
        ', ' +
        'version: ${version}' +
        ', ' +
        'name: ${name}' +
        ', ' +
        'description: ${description})';
  }

  /// Value equality that ignores the auto-generated `id`
  /// field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)`). See issue #127.
  bool valueEquals(Object other) {
    if (identical(this, other)) return true;
    return other is DynamicForm &&
        code == other.code &&
        version == other.version &&
        name == other.name &&
        description == other.description;
  }

  /// The full `toJson()` output with the auto-generated
  /// `id` field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)` ) removed. Use a
  /// canonical serialized representation (e.g.,
  /// `toJsonValue().toString()`) or an explicit value-key
  /// type for deduplication. See issue #127.
  Map<String, dynamic> toJsonValue() {
    final Map<String, dynamic> data = _$DynamicFormToJson(this);
    data.remove('id');
    return data;
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$DynamicFormToJson(this);
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

extension DynamicFormPropertyHelpers on DynamicForm {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasCode {
    return this.code.isNotEmpty;
  }

  bool get noCode {
    return this.code.isEmpty;
  }

  bool get hasName {
    return this.name.isNotEmpty;
  }

  bool get noName {
    return this.name.isEmpty;
  }

  bool get hasDescription {
    return this.description?.isNotEmpty == true;
  }

  bool get noDescription {
    return this.description?.isEmpty ?? true;
  }

  String get descriptionRequired {
    return this.description ??
        (throw StateError('description is required but was null'));
  }
}

extension DynamicFormSerialization on DynamicForm {
  Map<String, dynamic> toJson() {
    return _$DynamicFormToJson(this);
  }
}

enum DynamicForm$ { id, code, version, name_, description }

class DynamicFormPatch extends PatchBase<DynamicForm, DynamicForm$> {
  DynamicForm applyTo(DynamicForm entity) {
    return entity.patchWithDynamicForm(this);
  }

  DynamicFormPatch withId(String? value) {
    patchMap[DynamicForm$.id] = value;
    return this;
  }

  DynamicFormPatch withCode(String? value) {
    patchMap[DynamicForm$.code] = value;
    return this;
  }

  DynamicFormPatch withVersion(int? value) {
    patchMap[DynamicForm$.version] = value;
    return this;
  }

  DynamicFormPatch withName(String? value) {
    patchMap[DynamicForm$.name_] = value;
    return this;
  }

  DynamicFormPatch withDescription(String? value) {
    patchMap[DynamicForm$.description] = value;
    return this;
  }
}

/// Field descriptors for [DynamicForm] query construction
abstract final class DynamicFormFields {
  static const id = Field<DynamicForm, String>('id', _$id);

  static const code = Field<DynamicForm, String>('code', _$code);

  static const version = Field<DynamicForm, int>('version', _$version);

  static const name = Field<DynamicForm, String>('name', _$name);

  static const description = Field<DynamicForm, String?>(
    'description',
    _$description,
  );

  static String _$id(DynamicForm e) {
    return e.id;
  }

  static String _$code(DynamicForm e) {
    return e.code;
  }

  static int _$version(DynamicForm e) {
    return e.version;
  }

  static String _$name(DynamicForm e) {
    return e.name;
  }

  static String? _$description(DynamicForm e) {
    return e.description;
  }
}

extension DynamicFormCompareE on DynamicForm {
  Map<String, dynamic> compareToDynamicForm(DynamicForm other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (code != other.code) {
      diff['code'] = () => other.code;
    }

    if (version != other.version) {
      diff['version'] = () => other.version;
    }

    if (name != other.name) {
      diff['name'] = () => other.name;
    }

    if (description != other.description) {
      diff['description'] = () => other.description;
    }
    return diff;
  }
}
