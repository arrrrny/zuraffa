// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'create_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, genericArgumentFactories: true)
class CreateParams<T> extends Params {
  final T data;

  const CreateParams({Map<String, dynamic>? params, required this.data})
    : super(params: params);

  CreateParams copyWith({Map<String, dynamic>? params, T? data}) {
    return CreateParams(params: params ?? this.params, data: data ?? this.data);
  }

  CreateParams copyWithCreateParams({Map<String, dynamic>? params, T? data}) {
    return copyWith(params: params, data: data);
  }

  CreateParams copyWithParams({Map<String, dynamic>? params}) {
    return copyWith(params: params);
  }

  CreateParams patchWithCreateParams({CreateParamsPatch? patchInput}) {
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

  CreateParams patchWithParams({ParamsPatch? patchInput}) {
    final _patcher = patchInput ?? ParamsPatch();
    final _patchMap = _patcher.patchMap;
    return CreateParams(
      params: _patchMap.containsKey(Params$.params)
          ? (_patchMap[Params$.params] is Function)
                ? _patchMap[Params$.params](this.params)
                : (_patchMap[Params$.params] is Patch)
                ? _patchMap[Params$.params].applyTo(this.params)
                : _patchMap[Params$.params]
          : this.params,
      data: this.data,
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

  /// Creates a [CreateParams] instance from JSON
  factory CreateParams.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) => _$CreateParamsFromJson(json, fromJsonT);
}

extension CreateParamsPropertyHelpers<T> on CreateParams<T> {}

extension CreateParamsSerialization<T> on CreateParams<T> {
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$CreateParamsToJson(this, toJsonT);
  Map<String, dynamic> toJsonLean(Object? Function(T value) toJsonT) {
    final Map<String, dynamic> data = _$CreateParamsToJson(this, toJsonT);
    return _sanitizeJson(data);
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

enum CreateParams$ { params, data }

class CreateParamsPatch extends PatchBase<CreateParams, CreateParams$> {
  CreateParams applyTo(CreateParams entity) {
    return entity.patchWithCreateParams(patchInput: this);
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
abstract final class CreateParamsFields {
  static Map<String, dynamic>? _$getparams<T>(CreateParams<T> e) => e.params;
  static Field<CreateParams<T>, Map<String, dynamic>?> params<T>() =>
      Field<CreateParams<T>, Map<String, dynamic>?>('params', _$getparams<T>);
  static T _$getdata<T>(CreateParams<T> e) => e.data;
  static Field<CreateParams<T>, T> data<T>() =>
      Field<CreateParams<T>, T>('data', _$getdata<T>);
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
