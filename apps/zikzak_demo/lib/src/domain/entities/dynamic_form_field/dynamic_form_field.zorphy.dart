// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'dynamic_form_field.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class DynamicFormField {
  DynamicFormField({
    String? id,
    required String this.code,
    required DynamicFormFieldType this.type,
    required String this.label,
    String? this.placeholder,
    required bool this.required,
    List<String>? this.options,
  }) : this.id = id ?? const Uuid().v4();

  factory DynamicFormField.fromJson(Map<String, dynamic> json) =>
      _$DynamicFormFieldFromJson(json);

  final String id;

  final String code;

  final DynamicFormFieldType type;

  final String label;

  final String? placeholder;

  final bool required;

  final List<String>? options;

  DynamicFormField copyWith({
    String? id,
    String? code,
    DynamicFormFieldType? type,
    String? label,
    String? placeholder,
    bool? required,
    List<String>? options,
  }) {
    return DynamicFormField(
      id: id ?? this.id,
      code: code ?? this.code,
      type: type ?? this.type,
      label: label ?? this.label,
      placeholder: placeholder ?? this.placeholder,
      required: required ?? this.required,
      options: options ?? this.options,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  DynamicFormField copyWithField<T>(Field<DynamicFormField, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'code':
        return copyWith(code: value as String);
      case 'type':
        return copyWith(type: value as DynamicFormFieldType);
      case 'label':
        return copyWith(label: value as String);
      case 'placeholder':
        return copyWith(placeholder: value as String?);
      case 'required':
        return copyWith(required: value as bool);
      case 'options':
        return copyWith(options: value as List<String>?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'DynamicFormField has no settable field with this name',
        );
    }
  }

  DynamicFormField copyWithDynamicFormField({
    String? id,
    String? code,
    DynamicFormFieldType? type,
    String? label,
    String? placeholder,
    bool? required,
    List<String>? options,
  }) {
    return copyWith(
      id: id,
      code: code,
      type: type,
      label: label,
      placeholder: placeholder,
      required: required,
      options: options,
    );
  }

  DynamicFormField patchWithDynamicFormField([
    DynamicFormFieldPatch? patchInput,
  ]) {
    final _patcher = patchInput ?? DynamicFormFieldPatch();
    final _patchMap = _patcher.patchMap;
    return DynamicFormField(
      id: _patchMap.containsKey(DynamicFormField$.id)
          ? ((_patchMap[DynamicFormField$.id] is Function)
                    ? _patchMap[DynamicFormField$.id](this.id)
                    : (_patchMap[DynamicFormField$.id] is Patch)
                    ? _patchMap[DynamicFormField$.id].applyTo(this.id)
                    : _patchMap[DynamicFormField$.id])
                as String
          : this.id,
      code: _patchMap.containsKey(DynamicFormField$.code)
          ? ((_patchMap[DynamicFormField$.code] is Function)
                    ? _patchMap[DynamicFormField$.code](this.code)
                    : (_patchMap[DynamicFormField$.code] is Patch)
                    ? _patchMap[DynamicFormField$.code].applyTo(this.code)
                    : _patchMap[DynamicFormField$.code])
                as String
          : this.code,
      type: _patchMap.containsKey(DynamicFormField$.type)
          ? ((_patchMap[DynamicFormField$.type] is Function)
                    ? _patchMap[DynamicFormField$.type](this.type)
                    : (_patchMap[DynamicFormField$.type] is Patch)
                    ? _patchMap[DynamicFormField$.type].applyTo(this.type)
                    : _patchMap[DynamicFormField$.type])
                as DynamicFormFieldType
          : this.type,
      label: _patchMap.containsKey(DynamicFormField$.label)
          ? ((_patchMap[DynamicFormField$.label] is Function)
                    ? _patchMap[DynamicFormField$.label](this.label)
                    : (_patchMap[DynamicFormField$.label] is Patch)
                    ? _patchMap[DynamicFormField$.label].applyTo(this.label)
                    : _patchMap[DynamicFormField$.label])
                as String
          : this.label,
      placeholder: _patchMap.containsKey(DynamicFormField$.placeholder)
          ? ((_patchMap[DynamicFormField$.placeholder] is Function)
                    ? _patchMap[DynamicFormField$.placeholder](this.placeholder)
                    : (_patchMap[DynamicFormField$.placeholder] is Patch)
                    ? _patchMap[DynamicFormField$.placeholder].applyTo(
                        this.placeholder,
                      )
                    : _patchMap[DynamicFormField$.placeholder])
                as String?
          : this.placeholder,
      required: _patchMap.containsKey(DynamicFormField$.required)
          ? ((_patchMap[DynamicFormField$.required] is Function)
                    ? _patchMap[DynamicFormField$.required](this.required)
                    : (_patchMap[DynamicFormField$.required] is Patch)
                    ? _patchMap[DynamicFormField$.required].applyTo(
                        this.required,
                      )
                    : _patchMap[DynamicFormField$.required])
                as bool
          : this.required,
      options: _patchMap.containsKey(DynamicFormField$.options)
          ? ((_patchMap[DynamicFormField$.options] is Function)
                    ? _patchMap[DynamicFormField$.options](this.options)
                    : (_patchMap[DynamicFormField$.options] is Patch)
                    ? _patchMap[DynamicFormField$.options].applyTo(this.options)
                    : _patchMap[DynamicFormField$.options])
                as List<String>?
          : this.options,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DynamicFormField &&
        id == other.id &&
        code == other.code &&
        type == other.type &&
        label == other.label &&
        placeholder == other.placeholder &&
        required == other.required &&
        options == other.options;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.code,
      this.type,
      this.label,
      this.placeholder,
      this.required,
      this.options,
    );
  }

  @override
  String toString() {
    return 'DynamicFormField(' +
        'id: ${id}' +
        ', ' +
        'code: ${code}' +
        ', ' +
        'type: ${type}' +
        ', ' +
        'label: ${label}' +
        ', ' +
        'placeholder: ${placeholder}' +
        ', ' +
        'required: ${required}' +
        ', ' +
        'options: ${options})';
  }

  /// Value equality that ignores the auto-generated `id`
  /// field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)`). See issue #127.
  bool valueEquals(Object other) {
    if (identical(this, other)) return true;
    return other is DynamicFormField &&
        code == other.code &&
        type == other.type &&
        label == other.label &&
        placeholder == other.placeholder &&
        required == other.required &&
        options == other.options;
  }

  /// The full `toJson()` output with the auto-generated
  /// `id` field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)` ) removed. Use a
  /// canonical serialized representation (e.g.,
  /// `toJsonValue().toString()`) or an explicit value-key
  /// type for deduplication. See issue #127.
  Map<String, dynamic> toJsonValue() {
    final Map<String, dynamic> data = _$DynamicFormFieldToJson(this);
    data.remove('id');
    return data;
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$DynamicFormFieldToJson(this);
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

extension DynamicFormFieldPropertyHelpers on DynamicFormField {
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

  bool get isTypeText {
    return this.type == DynamicFormFieldType.text;
  }

  bool get isTypeNumber {
    return this.type == DynamicFormFieldType.number;
  }

  bool get isTypeSelect {
    return this.type == DynamicFormFieldType.select;
  }

  bool get isTypeCheckbox {
    return this.type == DynamicFormFieldType.checkbox;
  }

  bool get isTypeDate {
    return this.type == DynamicFormFieldType.date;
  }

  bool get isTypeRating {
    return this.type == DynamicFormFieldType.rating;
  }

  bool get isTypeSlider {
    return this.type == DynamicFormFieldType.slider;
  }

  bool get hasLabel {
    return this.label.isNotEmpty;
  }

  bool get noLabel {
    return this.label.isEmpty;
  }

  bool get hasPlaceholder {
    return this.placeholder?.isNotEmpty == true;
  }

  bool get noPlaceholder {
    return this.placeholder?.isEmpty ?? true;
  }

  String get placeholderRequired {
    return this.placeholder ??
        (throw StateError('placeholder is required but was null'));
  }

  List<String> get optionsRequired {
    return this.options ??
        (throw StateError('options is required but was null'));
  }

  bool get hasOptions {
    return this.options?.isNotEmpty ?? false;
  }

  bool get noOptions {
    return this.options?.isEmpty ?? true;
  }
}

extension DynamicFormFieldSerialization on DynamicFormField {
  Map<String, dynamic> toJson() {
    return _$DynamicFormFieldToJson(this);
  }
}

enum DynamicFormField$ { id, code, type, label, placeholder, required, options }

class DynamicFormFieldPatch
    extends PatchBase<DynamicFormField, DynamicFormField$> {
  DynamicFormField applyTo(DynamicFormField entity) {
    return entity.patchWithDynamicFormField(this);
  }

  DynamicFormFieldPatch withId(String? value) {
    patchMap[DynamicFormField$.id] = value;
    return this;
  }

  DynamicFormFieldPatch withCode(String? value) {
    patchMap[DynamicFormField$.code] = value;
    return this;
  }

  DynamicFormFieldPatch withType(DynamicFormFieldType? value) {
    patchMap[DynamicFormField$.type] = value;
    return this;
  }

  DynamicFormFieldPatch withLabel(String? value) {
    patchMap[DynamicFormField$.label] = value;
    return this;
  }

  DynamicFormFieldPatch withPlaceholder(String? value) {
    patchMap[DynamicFormField$.placeholder] = value;
    return this;
  }

  DynamicFormFieldPatch withRequired(bool? value) {
    patchMap[DynamicFormField$.required] = value;
    return this;
  }

  DynamicFormFieldPatch withOptions(List<String>? value) {
    patchMap[DynamicFormField$.options] = value;
    return this;
  }
}

/// Field descriptors for [DynamicFormField] query construction
abstract final class DynamicFormFieldFields {
  static const id = Field<DynamicFormField, String>('id', _$id);

  static const code = Field<DynamicFormField, String>('code', _$code);

  static const type = Field<DynamicFormField, DynamicFormFieldType>(
    'type',
    _$type,
  );

  static const label = Field<DynamicFormField, String>('label', _$label);

  static const placeholder = Field<DynamicFormField, String?>(
    'placeholder',
    _$placeholder,
  );

  static const required = Field<DynamicFormField, bool>('required', _$required);

  static const options = Field<DynamicFormField, List<String>?>(
    'options',
    _$options,
  );

  static String _$id(DynamicFormField e) {
    return e.id;
  }

  static String _$code(DynamicFormField e) {
    return e.code;
  }

  static DynamicFormFieldType _$type(DynamicFormField e) {
    return e.type;
  }

  static String _$label(DynamicFormField e) {
    return e.label;
  }

  static String? _$placeholder(DynamicFormField e) {
    return e.placeholder;
  }

  static bool _$required(DynamicFormField e) {
    return e.required;
  }

  static List<String>? _$options(DynamicFormField e) {
    return e.options;
  }
}

extension DynamicFormFieldCompareE on DynamicFormField {
  Map<String, dynamic> compareToDynamicFormField(DynamicFormField other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (code != other.code) {
      diff['code'] = () => other.code;
    }

    if (type != other.type) {
      diff['type'] = () => other.type;
    }

    if (label != other.label) {
      diff['label'] = () => other.label;
    }

    if (placeholder != other.placeholder) {
      diff['placeholder'] = () => other.placeholder;
    }

    if (required != other.required) {
      diff['required'] = () => other.required;
    }

    if (options != other.options) {
      diff['options'] = () => other.options;
    }
    return diff;
  }
}
