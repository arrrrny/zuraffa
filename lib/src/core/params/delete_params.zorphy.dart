// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'delete_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, genericArgumentFactories: true)
class DeleteParams<I> extends Params {
  final I id;

  const DeleteParams({Map<String, dynamic>? params, required this.id})
    : super(params: params);

  DeleteParams copyWith({Map<String, dynamic>? params, I? id}) {
    return DeleteParams(params: params ?? this.params, id: id ?? this.id);
  }

  DeleteParams copyWithDeleteParams({Map<String, dynamic>? params, I? id}) {
    return copyWith(params: params, id: id);
  }

  DeleteParams copyWithParams({Map<String, dynamic>? params}) {
    return copyWith(params: params);
  }

  DeleteParams patchWithDeleteParams({DeleteParamsPatch? patchInput}) {
    final _patcher = patchInput ?? DeleteParamsPatch();
    final _patchMap = _patcher.patchMap;
    return DeleteParams(
      params: _patchMap.containsKey(DeleteParams$.params)
          ? (_patchMap[DeleteParams$.params] is Function)
                ? _patchMap[DeleteParams$.params](this.params)
                : (_patchMap[DeleteParams$.params] is Patch)
                ? _patchMap[DeleteParams$.params].applyTo(this.params)
                : _patchMap[DeleteParams$.params]
          : this.params,
      id: _patchMap.containsKey(DeleteParams$.id)
          ? (_patchMap[DeleteParams$.id] is Function)
                ? _patchMap[DeleteParams$.id](this.id)
                : (_patchMap[DeleteParams$.id] is Patch)
                ? _patchMap[DeleteParams$.id].applyTo(this.id)
                : _patchMap[DeleteParams$.id]
          : this.id,
    );
  }

  DeleteParams patchWithParams({ParamsPatch? patchInput}) {
    final _patcher = patchInput ?? ParamsPatch();
    final _patchMap = _patcher.patchMap;
    return DeleteParams(
      params: _patchMap.containsKey(Params$.params)
          ? (_patchMap[Params$.params] is Function)
                ? _patchMap[Params$.params](this.params)
                : (_patchMap[Params$.params] is Patch)
                ? _patchMap[Params$.params].applyTo(this.params)
                : _patchMap[Params$.params]
          : this.params,
      id: this.id,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeleteParams && params == other.params && id == other.id;
  }

  @override
  int get hashCode {
    return Object.hash(this.params, this.id);
  }

  @override
  String toString() {
    return 'DeleteParams(' + 'params: ${params}' + ', ' + 'id: ${id})';
  }

  /// Creates a [DeleteParams] instance from JSON
  factory DeleteParams.fromJson(
    Map<String, dynamic> json,
    I Function(Object? json) fromJsonI,
  ) => _$DeleteParamsFromJson(json, fromJsonI);
}

extension DeleteParamsPropertyHelpers<I> on DeleteParams<I> {}

extension DeleteParamsSerialization<I> on DeleteParams<I> {
  Map<String, dynamic> toJson(Object? Function(I value) toJsonI) =>
      _$DeleteParamsToJson(this, toJsonI);
  Map<String, dynamic> toJsonLean(Object? Function(I value) toJsonI) {
    final Map<String, dynamic> data = _$DeleteParamsToJson(this, toJsonI);
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

enum DeleteParams$ { params, id }

class DeleteParamsPatch extends PatchBase<DeleteParams, DeleteParams$> {
  DeleteParams applyTo(DeleteParams entity) {
    return entity.patchWithDeleteParams(patchInput: this);
  }

  DeleteParamsPatch withParams(Map<String, dynamic>? value) {
    patchMap[DeleteParams$.params] = value;
    return this;
  }

  DeleteParamsPatch withId(dynamic value) {
    patchMap[DeleteParams$.id] = value;
    return this;
  }
}

/// Field descriptors for [DeleteParams] query construction
abstract final class DeleteParamsFields {
  static Map<String, dynamic>? _$getparams<I>(DeleteParams<I> e) => e.params;
  static Field<DeleteParams<I>, Map<String, dynamic>?> params<I>() =>
      Field<DeleteParams<I>, Map<String, dynamic>?>('params', _$getparams<I>);
  static I _$getid<I>(DeleteParams<I> e) => e.id;
  static Field<DeleteParams<I>, I> id<I>() =>
      Field<DeleteParams<I>, I>('id', _$getid<I>);
}

extension DeleteParamsCompareE on DeleteParams {
  Map<String, dynamic> compareToDeleteParams(DeleteParams other) {
    final Map<String, dynamic> diff = {};

    if (params != other.params) {
      diff['params'] = () => other.params;
    }
    if (id != other.id) {
      diff['id'] = () => other.id;
    }
    return diff;
  }
}
