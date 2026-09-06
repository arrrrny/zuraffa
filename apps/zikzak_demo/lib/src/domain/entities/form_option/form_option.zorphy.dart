// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'form_option.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class FormOption {
  FormOption({
    String? id,
    required String this.value,
    required String this.label,
  }) : this.id = id ?? const Uuid().v4();

  factory FormOption.fromJson(Map<String, dynamic> json) =>
      _$FormOptionFromJson(json);

  final String id;

  final String value;

  final String label;

  FormOption copyWith({String? id, String? value, String? label}) {
    return FormOption(
      id: id ?? this.id,
      value: value ?? this.value,
      label: label ?? this.label,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  FormOption copyWithField<T>(Field<FormOption, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'value':
        return copyWith(value: value as String);
      case 'label':
        return copyWith(label: value as String);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'FormOption has no settable field with this name',
        );
    }
  }

  FormOption copyWithFormOption({String? id, String? value, String? label}) {
    return copyWith(id: id, value: value, label: label);
  }

  FormOption patchWithFormOption([FormOptionPatch? patchInput]) {
    final _patcher = patchInput ?? FormOptionPatch();
    final _patchMap = _patcher.patchMap;
    return FormOption(
      id: _patchMap.containsKey(FormOption$.id)
          ? ((_patchMap[FormOption$.id] is Function)
                    ? _patchMap[FormOption$.id](this.id)
                    : (_patchMap[FormOption$.id] is Patch)
                    ? _patchMap[FormOption$.id].applyTo(this.id)
                    : _patchMap[FormOption$.id])
                as String
          : this.id,
      value: _patchMap.containsKey(FormOption$.value)
          ? ((_patchMap[FormOption$.value] is Function)
                    ? _patchMap[FormOption$.value](this.value)
                    : (_patchMap[FormOption$.value] is Patch)
                    ? _patchMap[FormOption$.value].applyTo(this.value)
                    : _patchMap[FormOption$.value])
                as String
          : this.value,
      label: _patchMap.containsKey(FormOption$.label)
          ? ((_patchMap[FormOption$.label] is Function)
                    ? _patchMap[FormOption$.label](this.label)
                    : (_patchMap[FormOption$.label] is Patch)
                    ? _patchMap[FormOption$.label].applyTo(this.label)
                    : _patchMap[FormOption$.label])
                as String
          : this.label,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FormOption &&
        id == other.id &&
        value == other.value &&
        label == other.label;
  }

  @override
  int get hashCode {
    return Object.hash(this.id, this.value, this.label);
  }

  @override
  String toString() {
    return 'FormOption(' +
        'id: ${id}' +
        ', ' +
        'value: ${value}' +
        ', ' +
        'label: ${label})';
  }

  /// Value equality that ignores the auto-generated `id`
  /// field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)`). See issue #127.
  bool valueEquals(Object other) {
    if (identical(this, other)) return true;
    return other is FormOption && value == other.value && label == other.label;
  }

  /// The full `toJson()` output with the auto-generated
  /// `id` field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)` ) removed. Use a
  /// canonical serialized representation (e.g.,
  /// `toJsonValue().toString()`) or an explicit value-key
  /// type for deduplication. See issue #127.
  Map<String, dynamic> toJsonValue() {
    final Map<String, dynamic> data = _$FormOptionToJson(this);
    data.remove('id');
    return data;
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$FormOptionToJson(this);
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

extension FormOptionPropertyHelpers on FormOption {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasValue {
    return this.value.isNotEmpty;
  }

  bool get noValue {
    return this.value.isEmpty;
  }

  bool get hasLabel {
    return this.label.isNotEmpty;
  }

  bool get noLabel {
    return this.label.isEmpty;
  }
}

extension FormOptionSerialization on FormOption {
  Map<String, dynamic> toJson() {
    return _$FormOptionToJson(this);
  }
}

enum FormOption$ { id, value, label }

class FormOptionPatch extends PatchBase<FormOption, FormOption$> {
  FormOption applyTo(FormOption entity) {
    return entity.patchWithFormOption(this);
  }

  FormOptionPatch withId(String? value) {
    patchMap[FormOption$.id] = value;
    return this;
  }

  FormOptionPatch withValue(String? value) {
    patchMap[FormOption$.value] = value;
    return this;
  }

  FormOptionPatch withLabel(String? value) {
    patchMap[FormOption$.label] = value;
    return this;
  }
}

/// Field descriptors for [FormOption] query construction
abstract final class FormOptionFields {
  static const id = Field<FormOption, String>('id', _$id);

  static const value = Field<FormOption, String>('value', _$value);

  static const label = Field<FormOption, String>('label', _$label);

  static String _$id(FormOption e) {
    return e.id;
  }

  static String _$value(FormOption e) {
    return e.value;
  }

  static String _$label(FormOption e) {
    return e.label;
  }
}

extension FormOptionCompareE on FormOption {
  Map<String, dynamic> compareToFormOption(FormOption other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (value != other.value) {
      diff['value'] = () => other.value;
    }

    if (label != other.label) {
      diff['label'] = () => other.label;
    }
    return diff;
  }
}
