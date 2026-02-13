// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'delete_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, genericArgumentFactories: true)
class DeleteParams<I> {
  final I id;
  final Params? params;

  const DeleteParams({required this.id, this.params});

  DeleteParams copyWith({I? id, Params? params}) {
    return DeleteParams(id: id ?? this.id, params: params ?? this.params);
  }

  DeleteParams copyWithDeleteParams({I? id, Params? params}) {
    return copyWith(id: id, params: params);
  }

  DeleteParams patchWithDeleteParams({DeleteParamsPatch? patchInput}) {
    final _patcher = patchInput ?? DeleteParamsPatch();
    final _patchMap = _patcher.toPatch();
    return DeleteParams(
      id: _patchMap.containsKey(DeleteParams$.id)
          ? (_patchMap[DeleteParams$.id] is Function)
                ? _patchMap[DeleteParams$.id](this.id)
                : _patchMap[DeleteParams$.id]
          : this.id,
      params: _patchMap.containsKey(DeleteParams$.params)
          ? (_patchMap[DeleteParams$.params] is Function)
                ? _patchMap[DeleteParams$.params](this.params)
                : _patchMap[DeleteParams$.params]
          : this.params,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeleteParams && id == other.id && params == other.params;
  }

  @override
  int get hashCode {
    return Object.hash(this.id, this.params);
  }

  @override
  String toString() {
    return 'DeleteParams(' + 'id: ${id}' + ', ' + 'params: ${params})';
  }

  /// Creates a [DeleteParams] instance from JSON
  factory DeleteParams.fromJson(
    Map<String, dynamic> json,
    I Function(Object? json) fromJsonI,
  ) => _$DeleteParamsFromJson(json, fromJsonI);

  Map<String, dynamic> toJsonLean(Object? Function(I value) toJsonI) {
    final Map<String, dynamic> data = _$DeleteParamsToJson(this, toJsonI);
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

extension DeleteParamsPropertyHelpers<I> on DeleteParams<I> {
  bool get hasParams => params != null;
  bool get noParams => params == null;
  Params get paramsRequired =>
      params ?? (throw StateError('params is required but was null'));
}

extension DeleteParamsSerialization<I> on DeleteParams<I> {
  Map<String, dynamic> toJson(Object? Function(I value) toJsonI) =>
      _$DeleteParamsToJson(this, toJsonI);
  Map<String, dynamic> toJsonLean(Object? Function(I value) toJsonI) {
    final Map<String, dynamic> data = _$DeleteParamsToJson(this, toJsonI);
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

enum DeleteParams$ { id, params }

class DeleteParamsPatch implements Patch<DeleteParams> {
  final Map<DeleteParams$, dynamic> _patch = {};

  static DeleteParamsPatch create([Map<String, dynamic>? diff]) {
    final patch = DeleteParamsPatch();
    if (diff != null) {
      diff.forEach((key, value) {
        try {
          final enumValue = DeleteParams$.values.firstWhere(
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

  static DeleteParamsPatch fromPatch(Map<DeleteParams$, dynamic> patch) {
    final _patch = DeleteParamsPatch();
    _patch._patch.addAll(patch);
    return _patch;
  }

  Map<DeleteParams$, dynamic> toPatch() => Map.from(_patch);

  DeleteParams applyTo(DeleteParams entity) {
    return entity.patchWithDeleteParams(patchInput: this);
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

  static DeleteParamsPatch fromJson(Map<String, dynamic> json) {
    return create(json);
  }

  DeleteParamsPatch withId(dynamic value) {
    _patch[DeleteParams$.id] = value;
    return this;
  }

  DeleteParamsPatch withParams(Params? value) {
    _patch[DeleteParams$.params] = value;
    return this;
  }
}

/// Field descriptors for [DeleteParams] query construction
abstract final class DeleteParamsFields {
  static I _$getid<I>(DeleteParams<I> e) => e.id;
  static Field<DeleteParams<I>, I> id<I>() =>
      Field<DeleteParams<I>, I>('id', _$getid<I>);
  static Params? _$getparams<I>(DeleteParams<I> e) => e.params;
  static Field<DeleteParams<I>, Params?> params<I>() =>
      Field<DeleteParams<I>, Params?>('params', _$getparams<I>);
}

extension DeleteParamsCompareE on DeleteParams {
  Map<String, dynamic> compareToDeleteParams(DeleteParams other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }
    if (params != other.params) {
      diff['params'] = () => other.params;
    }
    return diff;
  }
}
