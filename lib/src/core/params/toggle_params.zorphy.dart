// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'toggle_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(
  explicitToJson: true,
  checked: true,
  genericArgumentFactories: true,
)
class ToggleParams<I, F> extends Params {
  const ToggleParams({
    Map<String, dynamic>? this.params,
    required I this.id,
    required F this.field,
    required bool this.value,
  }) : super();

  factory ToggleParams.fromJson(
    Map<String, dynamic> json,
    I Function(Object? json) fromJsonI,
    F Function(Object? json) fromJsonF,
  ) => _$ToggleParamsFromJson(json, fromJsonI, fromJsonF);

  @override
  final Map<String, dynamic>? params;

  final I id;

  final F field;

  final bool value;

  ToggleParams copyWith({
    Map<String, dynamic>? params,
    I? id,
    F? field,
    bool? value,
  }) {
    return ToggleParams(
      params: params ?? this.params,
      id: id ?? this.id,
      field: field ?? this.field,
      value: value ?? this.value,
    );
  }

  ToggleParams copyWithToggleParams({
    Map<String, dynamic>? params,
    I? id,
    F? field,
    bool? value,
  }) {
    return copyWith(params: params, id: id, field: field, value: value);
  }

  ToggleParams patchWithToggleParams([ToggleParamsPatch? patchInput]) {
    final _patcher = patchInput ?? ToggleParamsPatch();
    final _patchMap = _patcher.patchMap;
    return ToggleParams(
      params: _patchMap.containsKey(ToggleParams$.params)
          ? ((_patchMap[ToggleParams$.params] is Function)
                    ? _patchMap[ToggleParams$.params](this.params)
                    : (_patchMap[ToggleParams$.params] is Patch)
                    ? _patchMap[ToggleParams$.params].applyTo(this.params)
                    : _patchMap[ToggleParams$.params])
                as Map<String, dynamic>?
          : this.params,
      id: _patchMap.containsKey(ToggleParams$.id)
          ? ((_patchMap[ToggleParams$.id] is Function)
                    ? _patchMap[ToggleParams$.id](this.id)
                    : (_patchMap[ToggleParams$.id] is Patch)
                    ? _patchMap[ToggleParams$.id].applyTo(this.id)
                    : _patchMap[ToggleParams$.id])
                as I
          : this.id,
      field: _patchMap.containsKey(ToggleParams$.field)
          ? ((_patchMap[ToggleParams$.field] is Function)
                    ? _patchMap[ToggleParams$.field](this.field)
                    : (_patchMap[ToggleParams$.field] is Patch)
                    ? _patchMap[ToggleParams$.field].applyTo(this.field)
                    : _patchMap[ToggleParams$.field])
                as F
          : this.field,
      value: _patchMap.containsKey(ToggleParams$.value)
          ? ((_patchMap[ToggleParams$.value] is Function)
                    ? _patchMap[ToggleParams$.value](this.value)
                    : (_patchMap[ToggleParams$.value] is Patch)
                    ? _patchMap[ToggleParams$.value].applyTo(this.value)
                    : _patchMap[ToggleParams$.value])
                as bool
          : this.value,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToggleParams &&
        params == other.params &&
        id == other.id &&
        field == other.field &&
        value == other.value;
  }

  @override
  int get hashCode {
    return Object.hash(this.params, this.id, this.field, this.value);
  }

  @override
  String toString() {
    return 'ToggleParams(' +
        'params: ${params}' +
        ', ' +
        'id: ${id}' +
        ', ' +
        'field: ${field}' +
        ', ' +
        'value: ${value})';
  }
}

extension ToggleParamsPropertyHelpers<I, F> on ToggleParams<I, F> {}

extension ToggleParamsSerialization<I, F> on ToggleParams<I, F> {
  Map<String, dynamic> toJson(
    Object? Function(I value) toJsonI,
    Object? Function(F value) toJsonF,
  ) => _$ToggleParamsToJson(this, toJsonI, toJsonF);
}

enum ToggleParams$ { params, id, field, value }

class ToggleParamsPatch extends PatchBase<ToggleParams, ToggleParams$> {
  ToggleParams applyTo(ToggleParams entity) {
    return entity.patchWithToggleParams(this);
  }

  ToggleParamsPatch withParams(Map<String, dynamic>? value) {
    patchMap[ToggleParams$.params] = value;
    return this;
  }

  ToggleParamsPatch withId(dynamic value) {
    patchMap[ToggleParams$.id] = value;
    return this;
  }

  ToggleParamsPatch withField(dynamic value) {
    patchMap[ToggleParams$.field] = value;
    return this;
  }

  ToggleParamsPatch withValue(bool? value) {
    patchMap[ToggleParams$.value] = value;
    return this;
  }
}

/// Field descriptors for [ToggleParams] query construction
abstract final class ToggleParamsFields<I, F> {
  static Map<String, dynamic>? _$params<I, F>(ToggleParams<I, F> e) {
    return e.params;
  }

  static Field<ToggleParams<I, F>, Map<String, dynamic>?> params<I, F>() {
    return Field<ToggleParams<I, F>, Map<String, dynamic>?>(
      'params',
      _$params<I, F>,
    );
  }

  static I _$id<I, F>(ToggleParams<I, F> e) {
    return e.id;
  }

  static Field<ToggleParams<I, F>, I> id<I, F>() {
    return Field<ToggleParams<I, F>, I>('id', _$id<I, F>);
  }

  static F _$field<I, F>(ToggleParams<I, F> e) {
    return e.field;
  }

  static Field<ToggleParams<I, F>, F> field<I, F>() {
    return Field<ToggleParams<I, F>, F>('field', _$field<I, F>);
  }

  static bool _$value<I, F>(ToggleParams<I, F> e) {
    return e.value;
  }

  static Field<ToggleParams<I, F>, bool> value<I, F>() {
    return Field<ToggleParams<I, F>, bool>('value', _$value<I, F>);
  }
}

extension ToggleParamsCompareE on ToggleParams {
  Map<String, dynamic> compareToToggleParams(ToggleParams other) {
    final Map<String, dynamic> diff = {};

    if (params != other.params) {
      diff['params'] = () => other.params;
    }

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (field != other.field) {
      diff['field'] = () => other.field;
    }

    if (value != other.value) {
      diff['value'] = () => other.value;
    }
    return diff;
  }
}
