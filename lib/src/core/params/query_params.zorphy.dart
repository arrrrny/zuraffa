// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'query_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(
  explicitToJson: true,
  checked: true,
  genericArgumentFactories: true,
)
class QueryParams<T> extends Params {
  const QueryParams({Map<String, dynamic>? this.params, Filter<T>? this.filter})
    : super();

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

  @override
  final Map<String, dynamic>? params;

  @JsonKey(
    includeFromJson: false,
    includeToJson: false,
    toJson: FilterConverter.toJson,
    fromJson: FilterConverter.fromJson,
  )
  final Filter<T>? filter;

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

  QueryParams patchWithQueryParams([QueryParamsPatch? patchInput]) {
    final _patcher = patchInput ?? QueryParamsPatch();
    final _patchMap = _patcher.patchMap;
    return QueryParams(
      params: _patchMap.containsKey(QueryParams$.params)
          ? ((_patchMap[QueryParams$.params] is Function)
                    ? _patchMap[QueryParams$.params](this.params)
                    : (_patchMap[QueryParams$.params] is Patch)
                    ? _patchMap[QueryParams$.params].applyTo(this.params)
                    : _patchMap[QueryParams$.params])
                as Map<String, dynamic>?
          : this.params,
      filter: _patchMap.containsKey(QueryParams$.filter)
          ? ((_patchMap[QueryParams$.filter] is Function)
                    ? _patchMap[QueryParams$.filter](this.filter)
                    : (_patchMap[QueryParams$.filter] is Patch)
                    ? _patchMap[QueryParams$.filter].applyTo(this.filter)
                    : _patchMap[QueryParams$.filter])
                as Filter<T>?
          : this.filter,
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
}

extension QueryParamsPropertyHelpers<T> on QueryParams<T> {
  bool get hasFilter {
    return this.filter != null;
  }

  bool get noFilter {
    return this.filter == null;
  }

  Filter<T> get filterRequired {
    return this.filter ?? (throw StateError('filter is required but was null'));
  }
}

extension QueryParamsSerialization<T> on QueryParams<T> {
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) {
    final data = _$QueryParamsToJson(this, toJsonT);
    if (filter != null) data['filter'] = FilterConverter.toJson(filter!);
    return data;
  }
}

enum QueryParams$ { params, filter }

class QueryParamsPatch extends PatchBase<QueryParams, QueryParams$> {
  QueryParams applyTo(QueryParams entity) {
    return entity.patchWithQueryParams(this);
  }

  QueryParamsPatch withParams(Map<String, dynamic>? value) {
    patchMap[QueryParams$.params] = value;
    return this;
  }

  QueryParamsPatch withFilter(dynamic value) {
    patchMap[QueryParams$.filter] = value;
    return this;
  }
}

/// Field descriptors for [QueryParams] query construction
abstract final class QueryParamsFields<T> {
  static Map<String, dynamic>? _$params<T>(QueryParams<T> e) {
    return e.params;
  }

  static Field<QueryParams<T>, Map<String, dynamic>?> params<T>() {
    return Field<QueryParams<T>, Map<String, dynamic>?>('params', _$params<T>);
  }

  static Filter<T>? _$filter<T>(QueryParams<T> e) {
    return e.filter;
  }

  static Field<QueryParams<T>, Filter<T>?> filter<T>() {
    return Field<QueryParams<T>, Filter<T>?>('filter', _$filter<T>);
  }
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
