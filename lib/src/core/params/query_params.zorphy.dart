// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'query_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, genericArgumentFactories: true)
class QueryParams<T> extends Params {
  @JsonKey(
    includeFromJson: false,
    includeToJson: false,
    toJson: FilterConverter.toJson,
    fromJson: FilterConverter.fromJson,
  )
  final Filter<T>? filter;

  const QueryParams({Map<String, dynamic>? params, this.filter})
    : super(params: params);

  QueryParams copyWith({Map<String, dynamic>? params, Filter<T>? filter}) {
    return QueryParams(
      params: params ?? this.params,
      filter: filter ?? this.filter,
    );
  }

  QueryParams copyWithQueryParams({
    Map<String, dynamic>? params,
    Filter<T>? filter,
  }) {
    return copyWith(params: params, filter: filter);
  }

  QueryParams copyWithParams({Map<String, dynamic>? params}) {
    return copyWith(params: params);
  }

  QueryParams patchWithQueryParams({QueryParamsPatch? patchInput}) {
    final _patcher = patchInput ?? QueryParamsPatch();
    final _patchMap = _patcher.toPatch();
    return QueryParams(
      params: _patchMap.containsKey(QueryParams$.params)
          ? (_patchMap[QueryParams$.params] is Function)
                ? _patchMap[QueryParams$.params](this.params)
                : _patchMap[QueryParams$.params]
          : this.params,
      filter: _patchMap.containsKey(QueryParams$.filter)
          ? (_patchMap[QueryParams$.filter] is Function)
                ? _patchMap[QueryParams$.filter](this.filter)
                : _patchMap[QueryParams$.filter]
          : this.filter,
    );
  }

  QueryParams patchWithParams({ParamsPatch? patchInput}) {
    final _patcher = patchInput ?? ParamsPatch();
    final _patchMap = _patcher.toPatch();
    return QueryParams(
      params: _patchMap.containsKey(Params$.params)
          ? (_patchMap[Params$.params] is Function)
                ? _patchMap[Params$.params](this.params)
                : _patchMap[Params$.params]
          : this.params,
      filter: this.filter,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueryParams &&
        params == other.params &&
        filter == other.filter;
  }

  @override
  int get hashCode {
    return Object.hash(this.params, this.filter);
  }

  @override
  String toString() {
    return 'QueryParams(' + 'params: ${params}' + ', ' + 'filter: ${filter})';
  }

  /// Creates a [QueryParams] instance from JSON
  factory QueryParams.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    final instance = _$QueryParamsFromJson(json, fromJsonT);
    return QueryParams(
      params: instance.params,
      filter: json['filter'] != null
          ? FilterConverter.fromJson(json['filter'] as Map<String, dynamic>)
                as Filter<T>?
          : null,
    );
  }
}

extension QueryParamsPropertyHelpers<T> on QueryParams<T> {
  bool get hasFilter => filter != null;
  bool get noFilter => filter == null;
  Filter<T> get filterRequired =>
      filter ?? (throw StateError('filter is required but was null'));
}

extension QueryParamsSerialization<T> on QueryParams<T> {
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) {
    final data = _$QueryParamsToJson(this, toJsonT);
    data['params'] = params;
    if (filter != null) data['filter'] = FilterConverter.toJson(filter!);
    return data;
  }

  Map<String, dynamic> toJsonLean(Object? Function(T value) toJsonT) {
    final Map<String, dynamic> data = _$QueryParamsToJson(this, toJsonT);
    if (params != null) data['params'] = params;
    if (filter != null) data['filter'] = FilterConverter.toJson(filter!);
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

enum QueryParams$ { params, filter }

class QueryParamsPatch implements Patch<QueryParams> {
  final Map<QueryParams$, dynamic> _patch = {};

  static QueryParamsPatch create([Map<String, dynamic>? diff]) {
    final patch = QueryParamsPatch();
    if (diff != null) {
      diff.forEach((key, value) {
        try {
          final enumValue = QueryParams$.values.firstWhere(
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

  static QueryParamsPatch fromPatch(Map<QueryParams$, dynamic> patch) {
    final _patch = QueryParamsPatch();
    _patch._patch.addAll(patch);
    return _patch;
  }

  Map<QueryParams$, dynamic> toPatch() => Map.from(_patch);

  QueryParams applyTo(QueryParams entity) {
    return entity.patchWithQueryParams(patchInput: this);
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

  static QueryParamsPatch fromJson(Map<String, dynamic> json) {
    return create(json);
  }

  QueryParamsPatch withParams(Map<String, dynamic>? value) {
    _patch[QueryParams$.params] = value;
    return this;
  }

  QueryParamsPatch withFilter(dynamic value) {
    _patch[QueryParams$.filter] = value;
    return this;
  }
}

/// Field descriptors for [QueryParams] query construction
abstract final class QueryParamsFields {
  static Map<String, dynamic>? _$getparams<T>(QueryParams<T> e) => e.params;
  static Field<QueryParams<T>, Map<String, dynamic>?> params<T>() =>
      Field<QueryParams<T>, Map<String, dynamic>?>('params', _$getparams<T>);
  static Filter<T>? _$getfilter<T>(QueryParams<T> e) => e.filter;
  static Field<QueryParams<T>, Filter<T>?> filter<T>() =>
      Field<QueryParams<T>, Filter<T>?>('filter', _$getfilter<T>);
}

extension QueryParamsCompareE on QueryParams {
  Map<String, dynamic> compareToQueryParams(QueryParams other) {
    final Map<String, dynamic> diff = {};

    if (params != other.params) {
      diff['params'] = () => other.params;
    }
    if (filter != other.filter) {
      diff['filter'] = () => other.filter;
    }
    return diff;
  }
}
