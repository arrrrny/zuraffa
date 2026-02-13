// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'update_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, genericArgumentFactories: true)
class UpdateParams<I, P> extends Params {
  final I id;
  final P data;

  const UpdateParams({
    Map<String, dynamic>? params,
    required this.id,
    required this.data,
  }) : super(params: params);

  UpdateParams copyWith({Map<String, dynamic>? params, I? id, P? data}) {
    return UpdateParams(
      params: params ?? this.params,
      id: id ?? this.id,
      data: data ?? this.data,
    );
  }

  UpdateParams copyWithUpdateParams({
    Map<String, dynamic>? params,
    I? id,
    P? data,
  }) {
    return copyWith(params: params, id: id, data: data);
  }

  UpdateParams copyWithParams({Map<String, dynamic>? params}) {
    return copyWith(params: params);
  }

  UpdateParams patchWithUpdateParams({UpdateParamsPatch? patchInput}) {
    final _patcher = patchInput ?? UpdateParamsPatch();
    final _patchMap = _patcher.toPatch();
    return UpdateParams(
      params: _patchMap.containsKey(UpdateParams$.params)
          ? (_patchMap[UpdateParams$.params] is Function)
                ? _patchMap[UpdateParams$.params](this.params)
                : _patchMap[UpdateParams$.params]
          : this.params,
      id: _patchMap.containsKey(UpdateParams$.id)
          ? (_patchMap[UpdateParams$.id] is Function)
                ? _patchMap[UpdateParams$.id](this.id)
                : _patchMap[UpdateParams$.id]
          : this.id,
      data: _patchMap.containsKey(UpdateParams$.data)
          ? (_patchMap[UpdateParams$.data] is Function)
                ? _patchMap[UpdateParams$.data](this.data)
                : _patchMap[UpdateParams$.data]
          : this.data,
    );
  }

  UpdateParams patchWithParams({ParamsPatch? patchInput}) {
    final _patcher = patchInput ?? ParamsPatch();
    final _patchMap = _patcher.toPatch();
    return UpdateParams(
      params: _patchMap.containsKey(Params$.params)
          ? (_patchMap[Params$.params] is Function)
                ? _patchMap[Params$.params](this.params)
                : _patchMap[Params$.params]
          : this.params,
      id: this.id,
      data: this.data,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpdateParams &&
        params == other.params &&
        id == other.id &&
        data == other.data;
  }

  @override
  int get hashCode {
    return Object.hash(this.params, this.id, this.data);
  }

  @override
  String toString() {
    return 'UpdateParams(' +
        'params: ${params}' +
        ', ' +
        'id: ${id}' +
        ', ' +
        'data: ${data})';
  }

  /// Creates a [UpdateParams] instance from JSON
  factory UpdateParams.fromJson(
    Map<String, dynamic> json,
    I Function(Object? json) fromJsonI,
    P Function(Object? json) fromJsonP,
  ) => _$UpdateParamsFromJson(json, fromJsonI, fromJsonP);
}

extension UpdateParamsPropertyHelpers<I, P> on UpdateParams<I, P> {}

extension UpdateParamsSerialization<I, P> on UpdateParams<I, P> {
  Map<String, dynamic> toJson(
    Object? Function(I value) toJsonI,
    Object? Function(P value) toJsonP,
  ) {
    final data = _$UpdateParamsToJson(this, toJsonI, toJsonP);
    data['params'] = params;
    return data;
  }

  Map<String, dynamic> toJsonLean(
    Object? Function(I value) toJsonI,
    Object? Function(P value) toJsonP,
  ) {
    final Map<String, dynamic> data = _$UpdateParamsToJson(
      this,
      toJsonI,
      toJsonP,
    );
    if (params != null) data['params'] = params;
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

enum UpdateParams$ { params, id, data }

class UpdateParamsPatch implements Patch<UpdateParams> {
  final Map<UpdateParams$, dynamic> _patch = {};

  static UpdateParamsPatch create([Map<String, dynamic>? diff]) {
    final patch = UpdateParamsPatch();
    if (diff != null) {
      diff.forEach((key, value) {
        try {
          final enumValue = UpdateParams$.values.firstWhere(
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

  static UpdateParamsPatch fromPatch(Map<UpdateParams$, dynamic> patch) {
    final _patch = UpdateParamsPatch();
    _patch._patch.addAll(patch);
    return _patch;
  }

  Map<UpdateParams$, dynamic> toPatch() => Map.from(_patch);

  UpdateParams applyTo(UpdateParams entity) {
    return entity.patchWithUpdateParams(patchInput: this);
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

  static UpdateParamsPatch fromJson(Map<String, dynamic> json) {
    return create(json);
  }

  UpdateParamsPatch withParams(Map<String, dynamic>? value) {
    _patch[UpdateParams$.params] = value;
    return this;
  }

  UpdateParamsPatch withId(dynamic value) {
    _patch[UpdateParams$.id] = value;
    return this;
  }

  UpdateParamsPatch withData(dynamic value) {
    _patch[UpdateParams$.data] = value;
    return this;
  }
}

/// Field descriptors for [UpdateParams] query construction
abstract final class UpdateParamsFields {
  static Map<String, dynamic>? _$getparams<I, P>(UpdateParams<I, P> e) =>
      e.params;
  static Field<UpdateParams<I, P>, Map<String, dynamic>?> params<I, P>() =>
      Field<UpdateParams<I, P>, Map<String, dynamic>?>(
        'params',
        _$getparams<I, P>,
      );
  static I _$getid<I, P>(UpdateParams<I, P> e) => e.id;
  static Field<UpdateParams<I, P>, I> id<I, P>() =>
      Field<UpdateParams<I, P>, I>('id', _$getid<I, P>);
  static P _$getdata<I, P>(UpdateParams<I, P> e) => e.data;
  static Field<UpdateParams<I, P>, P> data<I, P>() =>
      Field<UpdateParams<I, P>, P>('data', _$getdata<I, P>);
}

extension UpdateParamsCompareE on UpdateParams {
  Map<String, dynamic> compareToUpdateParams(UpdateParams other) {
    final Map<String, dynamic> diff = {};

    if (params != other.params) {
      diff['params'] = () => other.params;
    }
    if (id != other.id) {
      diff['id'] = () => other.id;
    }
    if (data != other.data) {
      diff['data'] = () => other.data;
    }
    return diff;
  }
}
