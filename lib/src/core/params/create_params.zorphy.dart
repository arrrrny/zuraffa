// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'create_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, genericArgumentFactories: true)
class CreateParams<T> {
  final T data;
  final Params? params;

  const CreateParams({required this.data, this.params});

  CreateParams copyWith({T? data, Params? params}) {
    return CreateParams(data: data ?? this.data, params: params ?? this.params);
  }

  CreateParams copyWithCreateParams({T? data, Params? params}) {
    return copyWith(data: data, params: params);
  }

  CreateParams patchWithCreateParams({CreateParamsPatch? patchInput}) {
    final _patcher = patchInput ?? CreateParamsPatch();
    final _patchMap = _patcher.toPatch();
    return CreateParams(
      data: _patchMap.containsKey(CreateParams$.data)
          ? (_patchMap[CreateParams$.data] is Function)
                ? _patchMap[CreateParams$.data](this.data)
                : _patchMap[CreateParams$.data]
          : this.data,
      params: _patchMap.containsKey(CreateParams$.params)
          ? (_patchMap[CreateParams$.params] is Function)
                ? _patchMap[CreateParams$.params](this.params)
                : _patchMap[CreateParams$.params]
          : this.params,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateParams &&
        data == other.data &&
        params == other.params;
  }

  @override
  int get hashCode {
    return Object.hash(this.data, this.params);
  }

  @override
  String toString() {
    return 'CreateParams(' + 'data: ${data}' + ', ' + 'params: ${params})';
  }

  /// Creates a [CreateParams] instance from JSON
  factory CreateParams.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) => _$CreateParamsFromJson(json, fromJsonT);

  Map<String, dynamic> toJsonLean(Object? Function(T value) toJsonT) {
    final Map<String, dynamic> data = _$CreateParamsToJson(this, toJsonT);
    return _sanitizeJson(data);
  }

  dynamic _sanitizeJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      json.remove('_className_');
      return json..forEach((key, value) {
        json[key] = _sanitizeJson(value);
      });
    } else if (json is List) {
      return json.map((e) => _sanitizeJson(e)).toList();
    }
    return json;
  }
}

extension CreateParamsPropertyHelpers<T> on CreateParams<T> {
  bool get hasParams => params != null;
  bool get noParams => params == null;
  Params get paramsRequired =>
      params ?? (throw StateError('params is required but was null'));
}

extension CreateParamsSerialization<T> on CreateParams<T> {
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$CreateParamsToJson(this, toJsonT);
  Map<String, dynamic> toJsonLean(Object? Function(T value) toJsonT) {
    final Map<String, dynamic> data = _$CreateParamsToJson(this, toJsonT);
    return _sanitizeJson(data);
  }

  dynamic _sanitizeJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      json.remove('_className_');
      return json..forEach((key, value) {
        json[key] = _sanitizeJson(value);
      });
    } else if (json is List) {
      return json.map((e) => _sanitizeJson(e)).toList();
    }
    return json;
  }
}

enum CreateParams$ { data, params }

class CreateParamsPatch implements Patch<CreateParams> {
  final Map<CreateParams$, dynamic> _patch = {};

  static CreateParamsPatch create([Map<String, dynamic>? diff]) {
    final patch = CreateParamsPatch();
    if (diff != null) {
      diff.forEach((key, value) {
        try {
          final enumValue = CreateParams$.values.firstWhere(
            (e) => e.name == key,
          );
          if (value is Function) {
            patch._patch[enumValue] = value();
          } else {
            patch._patch[enumValue] = value;
          }
        } catch (_) {}
      });
    }
    return patch;
  }

  static CreateParamsPatch fromPatch(Map<CreateParams$, dynamic> patch) {
    final _patch = CreateParamsPatch();
    _patch._patch.addAll(patch);
    return _patch;
  }

  Map<CreateParams$, dynamic> toPatch() => Map.from(_patch);

  CreateParams applyTo(CreateParams entity) {
    return entity.patchWithCreateParams(patchInput: this);
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    _patch.forEach((key, value) {
      if (value != null) {
        if (value is Function) {
          final result = value();
          json[key.name] = _convertToJson(result);
        } else {
          json[key.name] = _convertToJson(value);
        }
      }
    });
    return json;
  }

  dynamic _convertToJson(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    if (value is Enum) return value.toString().split('.').last;
    if (value is List) return value.map((e) => _convertToJson(e)).toList();
    if (value is Map)
      return value.map((k, v) => MapEntry(k.toString(), _convertToJson(v)));
    if (value is num || value is bool || value is String) return value;
    try {
      if (value?.toJsonLean != null) return value.toJsonLean();
    } catch (_) {}
    if (value?.toJson != null) return value.toJson();
    return value.toString();
  }

  static CreateParamsPatch fromJson(Map<String, dynamic> json) {
    return create(json);
  }

  CreateParamsPatch withData(dynamic value) {
    _patch[CreateParams$.data] = value;
    return this;
  }

  CreateParamsPatch withParams(Params? value) {
    _patch[CreateParams$.params] = value;
    return this;
  }
}

/// Field descriptors for [CreateParams] query construction
abstract final class CreateParamsFields {
  static T _$getdata<T>(CreateParams<T> e) => e.data;
  static Field<CreateParams<T>, T> data<T>() =>
      Field<CreateParams<T>, T>('data', _$getdata<T>);
  static Params? _$getparams<T>(CreateParams<T> e) => e.params;
  static Field<CreateParams<T>, Params?> params<T>() =>
      Field<CreateParams<T>, Params?>('params', _$getparams<T>);
}

extension CreateParamsCompareE on CreateParams {
  Map<String, dynamic> compareToCreateParams(CreateParams other) {
    final Map<String, dynamic> diff = {};

    if (data != other.data) {
      diff['data'] = () => other.data;
    }
    if (params != other.params) {
      diff['params'] = () => other.params;
    }
    return diff;
  }
}
