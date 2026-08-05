// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'create_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(
  explicitToJson: true,
  checked: true,
  genericArgumentFactories: true,
)
class CreateParams<T> extends Params {
  const CreateParams({Map<String, dynamic>? this.params, required T this.data})
    : super();

  factory CreateParams.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) => _$CreateParamsFromJson(json, fromJsonT);

  @override
  final Map<String, dynamic>? params;

  final T data;

  CreateParams copyWith({Map<String, dynamic>? params, T? data}) {
    return CreateParams(params: params ?? this.params, data: data ?? this.data);
  }

  CreateParams copyWithCreateParams({Map<String, dynamic>? params, T? data}) {
    return copyWith(params: params, data: data);
  }

  CreateParams patchWithCreateParams([CreateParamsPatch? patchInput]) {
    final _patcher = patchInput ?? CreateParamsPatch();
    final _patchMap = _patcher.patchMap;
    return CreateParams(
      params: _patchMap.containsKey(CreateParams$.params)
          ? (_patchMap[CreateParams$.params] is Function)
                ? _patchMap[CreateParams$.params](this.params)
                : (_patchMap[CreateParams$.params] is Patch)
                ? _patchMap[CreateParams$.params].applyTo(this.params)
                : _patchMap[CreateParams$.params]
          : this.params,
      data: _patchMap.containsKey(CreateParams$.data)
          ? (_patchMap[CreateParams$.data] is Function)
                ? _patchMap[CreateParams$.data](this.data)
                : (_patchMap[CreateParams$.data] is Patch)
                ? _patchMap[CreateParams$.data].applyTo(this.data)
                : _patchMap[CreateParams$.data]
          : this.data,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateParams &&
        params == other.params &&
        data == other.data;
  }

  @override
  int get hashCode {
    return Object.hash(this.params, this.data);
  }

  @override
  String toString() {
    return 'CreateParams(' + 'params: ${params}' + ', ' + 'data: ${data})';
  }
}

extension CreateParamsPropertyHelpers<T> on CreateParams<T> {}

extension CreateParamsSerialization<T> on CreateParams<T> {
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$CreateParamsToJson(this, toJsonT);
}

enum CreateParams$ { params, data }

class CreateParamsPatch extends PatchBase<CreateParams, CreateParams$> {
  CreateParams applyTo(CreateParams entity) {
    return entity.patchWithCreateParams(this);
  }

  CreateParamsPatch withParams(Map<String, dynamic>? value) {
    patchMap[CreateParams$.params] = value;
    return this;
  }

  CreateParamsPatch withData(dynamic value) {
    patchMap[CreateParams$.data] = value;
    return this;
  }
}

/// Field descriptors for [CreateParams] query construction
abstract final class CreateParamsFields<T> {
  static Map<String, dynamic>? _$params<T>(CreateParams<T> e) {
    return e.params;
  }

  static Field<CreateParams<T>, Map<String, dynamic>?> params<T>() {
    return Field<CreateParams<T>, Map<String, dynamic>?>('params', _$params<T>);
  }

  static T _$data<T>(CreateParams<T> e) {
    return e.data;
  }

  static Field<CreateParams<T>, T> data<T>() {
    return Field<CreateParams<T>, T>('data', _$data<T>);
  }
}

extension CreateParamsCompareE on CreateParams {
  Map<String, dynamic> compareToCreateParams(CreateParams other) {
    final Map<String, dynamic> diff = {};

    if (params != other.params) {
      diff['params'] = () => other.params;
    }

    if (data != other.data) {
      diff['data'] = () => other.data;
    }
    return diff;
  }
}
