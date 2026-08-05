// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'delete_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(
  explicitToJson: true,
  checked: true,
  genericArgumentFactories: true,
)
class DeleteParams<I> extends Params {
  const DeleteParams({Map<String, dynamic>? this.params, required I this.id})
    : super();

  factory DeleteParams.fromJson(
    Map<String, dynamic> json,
    I Function(Object? json) fromJsonI,
  ) => _$DeleteParamsFromJson(json, fromJsonI);

  @override
  final Map<String, dynamic>? params;

  final I id;

  DeleteParams copyWith({Map<String, dynamic>? params, I? id}) {
    return DeleteParams(params: params ?? this.params, id: id ?? this.id);
  }

  DeleteParams copyWithDeleteParams({Map<String, dynamic>? params, I? id}) {
    return copyWith(params: params, id: id);
  }

  DeleteParams patchWithDeleteParams([DeleteParamsPatch? patchInput]) {
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
}

extension DeleteParamsPropertyHelpers<I> on DeleteParams<I> {}

extension DeleteParamsSerialization<I> on DeleteParams<I> {
  Map<String, dynamic> toJson(Object? Function(I value) toJsonI) =>
      _$DeleteParamsToJson(this, toJsonI);
}

enum DeleteParams$ { params, id }

class DeleteParamsPatch extends PatchBase<DeleteParams, DeleteParams$> {
  DeleteParams applyTo(DeleteParams entity) {
    return entity.patchWithDeleteParams(this);
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
abstract final class DeleteParamsFields<I> {
  static Map<String, dynamic>? _$params<I>(DeleteParams<I> e) {
    return e.params;
  }

  static Field<DeleteParams<I>, Map<String, dynamic>?> params<I>() {
    return Field<DeleteParams<I>, Map<String, dynamic>?>('params', _$params<I>);
  }

  static I _$id<I>(DeleteParams<I> e) {
    return e.id;
  }

  static Field<DeleteParams<I>, I> id<I>() {
    return Field<DeleteParams<I>, I>('id', _$id<I>);
  }
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
