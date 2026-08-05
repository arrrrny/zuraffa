// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'update_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(
  explicitToJson: true,
  checked: true,
  genericArgumentFactories: true,
)
class UpdateParams<I, P> extends Params {
  const UpdateParams({
    Map<String, dynamic>? this.params,
    required I this.id,
    required P this.data,
  }) : super();

  factory UpdateParams.fromJson(
    Map<String, dynamic> json,
    I Function(Object? json) fromJsonI,
    P Function(Object? json) fromJsonP,
  ) => _$UpdateParamsFromJson(json, fromJsonI, fromJsonP);

  @override
  final Map<String, dynamic>? params;

  final I id;

  final P data;

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

  UpdateParams patchWithUpdateParams([UpdateParamsPatch? patchInput]) {
    final _patcher = patchInput ?? UpdateParamsPatch();
    final _patchMap = _patcher.patchMap;
    return UpdateParams(
      params: _patchMap.containsKey(UpdateParams$.params)
          ? (_patchMap[UpdateParams$.params] is Function)
                ? _patchMap[UpdateParams$.params](this.params)
                : (_patchMap[UpdateParams$.params] is Patch)
                ? _patchMap[UpdateParams$.params].applyTo(this.params)
                : _patchMap[UpdateParams$.params]
          : this.params,
      id: _patchMap.containsKey(UpdateParams$.id)
          ? (_patchMap[UpdateParams$.id] is Function)
                ? _patchMap[UpdateParams$.id](this.id)
                : (_patchMap[UpdateParams$.id] is Patch)
                ? _patchMap[UpdateParams$.id].applyTo(this.id)
                : _patchMap[UpdateParams$.id]
          : this.id,
      data: _patchMap.containsKey(UpdateParams$.data)
          ? (_patchMap[UpdateParams$.data] is Function)
                ? _patchMap[UpdateParams$.data](this.data)
                : (_patchMap[UpdateParams$.data] is Patch)
                ? _patchMap[UpdateParams$.data].applyTo(this.data)
                : _patchMap[UpdateParams$.data]
          : this.data,
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
}

extension UpdateParamsPropertyHelpers<I, P> on UpdateParams<I, P> {}

extension UpdateParamsSerialization<I, P> on UpdateParams<I, P> {
  Map<String, dynamic> toJson(
    Object? Function(I value) toJsonI,
    Object? Function(P value) toJsonP,
  ) => _$UpdateParamsToJson(this, toJsonI, toJsonP);
}

enum UpdateParams$ { params, id, data }

class UpdateParamsPatch extends PatchBase<UpdateParams, UpdateParams$> {
  UpdateParams applyTo(UpdateParams entity) {
    return entity.patchWithUpdateParams(this);
  }

  UpdateParamsPatch withParams(Map<String, dynamic>? value) {
    patchMap[UpdateParams$.params] = value;
    return this;
  }

  UpdateParamsPatch withId(dynamic value) {
    patchMap[UpdateParams$.id] = value;
    return this;
  }

  UpdateParamsPatch withData(dynamic value) {
    patchMap[UpdateParams$.data] = value;
    return this;
  }
}

/// Field descriptors for [UpdateParams] query construction
abstract final class UpdateParamsFields<I, P> {
  static Map<String, dynamic>? _$params<I, P>(UpdateParams<I, P> e) {
    return e.params;
  }

  static Field<UpdateParams<I, P>, Map<String, dynamic>?> params<I, P>() {
    return Field<UpdateParams<I, P>, Map<String, dynamic>?>(
      'params',
      _$params<I, P>,
    );
  }

  static I _$id<I, P>(UpdateParams<I, P> e) {
    return e.id;
  }

  static Field<UpdateParams<I, P>, I> id<I, P>() {
    return Field<UpdateParams<I, P>, I>('id', _$id<I, P>);
  }

  static P _$data<I, P>(UpdateParams<I, P> e) {
    return e.data;
  }

  static Field<UpdateParams<I, P>, P> data<I, P>() {
    return Field<UpdateParams<I, P>, P>('data', _$data<I, P>);
  }
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
