// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'form_submission.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class FormSubmission {
  FormSubmission({
    String? id,
    required String this.templateId,
    required Map<String, dynamic> this.inputValues,
    required FormSubmissionStatus this.status,
  }) : this.id = id ?? const Uuid().v4();

  factory FormSubmission.fromJson(Map<String, dynamic> json) =>
      _$FormSubmissionFromJson(json);

  final String id;

  final String templateId;

  final Map<String, dynamic> inputValues;

  final FormSubmissionStatus status;

  FormSubmission copyWith({
    String? id,
    String? templateId,
    Map<String, dynamic>? inputValues,
    FormSubmissionStatus? status,
  }) {
    return FormSubmission(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      inputValues: inputValues ?? this.inputValues,
      status: status ?? this.status,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  FormSubmission copyWithField<T>(Field<FormSubmission, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'templateId':
        return copyWith(templateId: value as String);
      case 'inputValues':
        return copyWith(inputValues: value as Map<String, dynamic>);
      case 'status':
        return copyWith(status: value as FormSubmissionStatus);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'FormSubmission has no settable field with this name',
        );
    }
  }

  FormSubmission copyWithFormSubmission({
    String? id,
    String? templateId,
    Map<String, dynamic>? inputValues,
    FormSubmissionStatus? status,
  }) {
    return copyWith(
      id: id,
      templateId: templateId,
      inputValues: inputValues,
      status: status,
    );
  }

  FormSubmission patchWithFormSubmission([FormSubmissionPatch? patchInput]) {
    final _patcher = patchInput ?? FormSubmissionPatch();
    final _patchMap = _patcher.patchMap;
    return FormSubmission(
      id: _patchMap.containsKey(FormSubmission$.id)
          ? ((_patchMap[FormSubmission$.id] is Function)
                    ? _patchMap[FormSubmission$.id](this.id)
                    : (_patchMap[FormSubmission$.id] is Patch)
                    ? _patchMap[FormSubmission$.id].applyTo(this.id)
                    : _patchMap[FormSubmission$.id])
                as String
          : this.id,
      templateId: _patchMap.containsKey(FormSubmission$.templateId)
          ? ((_patchMap[FormSubmission$.templateId] is Function)
                    ? _patchMap[FormSubmission$.templateId](this.templateId)
                    : (_patchMap[FormSubmission$.templateId] is Patch)
                    ? _patchMap[FormSubmission$.templateId].applyTo(
                        this.templateId,
                      )
                    : _patchMap[FormSubmission$.templateId])
                as String
          : this.templateId,
      inputValues: _patchMap.containsKey(FormSubmission$.inputValues)
          ? ((_patchMap[FormSubmission$.inputValues] is Function)
                    ? _patchMap[FormSubmission$.inputValues](this.inputValues)
                    : (_patchMap[FormSubmission$.inputValues] is Patch)
                    ? _patchMap[FormSubmission$.inputValues].applyTo(
                        this.inputValues,
                      )
                    : _patchMap[FormSubmission$.inputValues])
                as Map<String, dynamic>
          : this.inputValues,
      status: _patchMap.containsKey(FormSubmission$.status)
          ? ((_patchMap[FormSubmission$.status] is Function)
                    ? _patchMap[FormSubmission$.status](this.status)
                    : (_patchMap[FormSubmission$.status] is Patch)
                    ? _patchMap[FormSubmission$.status].applyTo(this.status)
                    : _patchMap[FormSubmission$.status])
                as FormSubmissionStatus
          : this.status,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FormSubmission &&
        id == other.id &&
        templateId == other.templateId &&
        inputValues == other.inputValues &&
        status == other.status;
  }

  @override
  int get hashCode {
    return Object.hash(this.id, this.templateId, this.inputValues, this.status);
  }

  @override
  String toString() {
    return 'FormSubmission(' +
        'id: ${id}' +
        ', ' +
        'templateId: ${templateId}' +
        ', ' +
        'inputValues: ${inputValues}' +
        ', ' +
        'status: ${status})';
  }

  /// Value equality that ignores the auto-generated `id`
  /// field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)`). See issue #127.
  bool valueEquals(Object other) {
    if (identical(this, other)) return true;
    return other is FormSubmission &&
        templateId == other.templateId &&
        inputValues == other.inputValues &&
        status == other.status;
  }

  /// The full `toJson()` output with the auto-generated
  /// `id` field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)` ) removed. Use a
  /// canonical serialized representation (e.g.,
  /// `toJsonValue().toString()`) or an explicit value-key
  /// type for deduplication. See issue #127.
  Map<String, dynamic> toJsonValue() {
    final Map<String, dynamic> data = _$FormSubmissionToJson(this);
    data.remove('id');
    return data;
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$FormSubmissionToJson(this);
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

extension FormSubmissionPropertyHelpers on FormSubmission {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasTemplateId {
    return this.templateId.isNotEmpty;
  }

  bool get noTemplateId {
    return this.templateId.isEmpty;
  }

  bool get hasInputValues {
    return this.inputValues.isNotEmpty;
  }

  bool get noInputValues {
    return this.inputValues.isEmpty;
  }

  bool get isStatusDraft {
    return this.status == FormSubmissionStatus.draft;
  }

  bool get isStatusSubmitted {
    return this.status == FormSubmissionStatus.submitted;
  }

  bool get isStatusApproved {
    return this.status == FormSubmissionStatus.approved;
  }

  bool get isStatusRejected {
    return this.status == FormSubmissionStatus.rejected;
  }
}

extension FormSubmissionSerialization on FormSubmission {
  Map<String, dynamic> toJson() {
    return _$FormSubmissionToJson(this);
  }
}

enum FormSubmission$ { id, templateId, inputValues, status }

class FormSubmissionPatch extends PatchBase<FormSubmission, FormSubmission$> {
  FormSubmission applyTo(FormSubmission entity) {
    return entity.patchWithFormSubmission(this);
  }

  FormSubmissionPatch withId(String? value) {
    patchMap[FormSubmission$.id] = value;
    return this;
  }

  FormSubmissionPatch withTemplateId(String? value) {
    patchMap[FormSubmission$.templateId] = value;
    return this;
  }

  FormSubmissionPatch withInputValues(Map<String, dynamic>? value) {
    patchMap[FormSubmission$.inputValues] = value;
    return this;
  }

  FormSubmissionPatch withStatus(FormSubmissionStatus? value) {
    patchMap[FormSubmission$.status] = value;
    return this;
  }
}

/// Field descriptors for [FormSubmission] query construction
abstract final class FormSubmissionFields {
  static const id = Field<FormSubmission, String>('id', _$id);

  static const templateId = Field<FormSubmission, String>(
    'templateId',
    _$templateId,
  );

  static const inputValues = Field<FormSubmission, Map<String, dynamic>>(
    'inputValues',
    _$inputValues,
  );

  static const status = Field<FormSubmission, FormSubmissionStatus>(
    'status',
    _$status,
  );

  static String _$id(FormSubmission e) {
    return e.id;
  }

  static String _$templateId(FormSubmission e) {
    return e.templateId;
  }

  static Map<String, dynamic> _$inputValues(FormSubmission e) {
    return e.inputValues;
  }

  static FormSubmissionStatus _$status(FormSubmission e) {
    return e.status;
  }
}

extension FormSubmissionCompareE on FormSubmission {
  Map<String, dynamic> compareToFormSubmission(FormSubmission other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (templateId != other.templateId) {
      diff['templateId'] = () => other.templateId;
    }

    if (inputValues != other.inputValues) {
      diff['inputValues'] = () => other.inputValues;
    }

    if (status != other.status) {
      diff['status'] = () => other.status;
    }
    return diff;
  }
}
