// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'query_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, genericArgumentFactories: true)
class QueryParams<T> {
  @JsonKey(
    includeFromJson: false,
    includeToJson: false,
    toJson: FilterConverter.toJson,
    fromJson: FilterConverter.fromJson,
  )
  final Filter<T>? filter;
  final Params? params;

  const QueryParams({this.filter, this.params});

  QueryParams copyWith({Filter<T>? filter, Params? params}) {
    return QueryParams(
      filter: filter ?? this.filter,
      params: params ?? this.params,
    );
  }

  QueryParams copyWithQueryParams({Filter<T>? filter, Params? params}) {
    return copyWith(filter: filter, params: params);
  }

  QueryParams patchWithQueryParams({QueryParamsPatch? patchInput}) {
    final _patcher = patchInput ?? QueryParamsPatch();
    final _patchMap = _patcher.toPatch();
    return QueryParams(
      filter: _patchMap.containsKey(QueryParams$.filter)
          ? (_patchMap[QueryParams$.filter] is Function)
                ? _patchMap[QueryParams$.filter](this.filter)
                : _patchMap[QueryParams$.filter]
          : this.filter,
      params: _patchMap.containsKey(QueryParams$.params)
          ? (_patchMap[QueryParams$.params] is Function)
                ? _patchMap[QueryParams$.params](this.params)
                : _patchMap[QueryParams$.params]
          : this.params,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueryParams &&
        filter == other.filter &&
        params == other.params;
  }

  @override
  int get hashCode {
    return Object.hash(this.filter, this.params);
  }

  @override
  String toString() {
    return 'QueryParams(' + 'filter: ${filter}' + ', ' + 'params: ${params})';
  }

  /// Creates a [QueryParams] instance from JSON
  factory QueryParams.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    final instance = _$QueryParamsFromJson(json, fromJsonT);
    return QueryParams(
      filter: json['filter'] != null
          ? FilterConverter.fromJson(json['filter'] as Map<String, dynamic>)
                as Filter<T>?
          : null,
      params: instance.params,
    );
  }

  Map<String, dynamic> toJsonLean(Object? Function(T value) toJsonT) {
    final Map<String, dynamic> data = _$QueryParamsToJson(this, toJsonT);
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

extension QueryParamsPropertyHelpers<T> on QueryParams<T> {
  bool get hasFilter => filter != null;
  bool get noFilter => filter == null;
  Filter<T> get filterRequired =>
      filter ?? (throw StateError('filter is required but was null'));
  bool get hasParams => params != null;
  bool get noParams => params == null;
  Params get paramsRequired =>
      params ?? (throw StateError('params is required but was null'));
}

extension QueryParamsSerialization<T> on QueryParams<T> {
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) {
    final data = _$QueryParamsToJson(this, toJsonT);
    if (filter != null) data['filter'] = FilterConverter.toJson(filter!);
    return data;
  }

  Map<String, dynamic> toJsonLean(Object? Function(T value) toJsonT) {
    final Map<String, dynamic> data = _$QueryParamsToJson(this, toJsonT);
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

enum QueryParams$ { filter, params }

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

  QueryParamsPatch withFilter(dynamic value) {
    _patch[QueryParams$.filter] = value;
    return this;
  }

  QueryParamsPatch withParams(Params? value) {
    _patch[QueryParams$.params] = value;
    return this;
  }

  QueryParamsPatch withParamsPatch(ParamsPatch patch) {
    _patch[QueryParams$.params] = patch;
    return this;
  }

  QueryParamsPatch withParamsPatchFunc(
    ParamsPatch Function(ParamsPatch) patch,
  ) {
    _patch[QueryParams$.params] = (dynamic current) {
      var currentPatch = ParamsPatch();
      if (current != null) {
        currentPatch = current as ParamsPatch;
      }
      return patch(currentPatch);
    };
    return this;
  }
}

/// Field descriptors for [QueryParams] query construction
abstract final class QueryParamsFields {
  static Filter<T>? _$getfilter<T>(QueryParams<T> e) => e.filter;
  static Field<QueryParams<T>, Filter<T>?> filter<T>() =>
      Field<QueryParams<T>, Filter<T>?>('filter', _$getfilter<T>);
  static Params? _$getparams<T>(QueryParams<T> e) => e.params;
  static Field<QueryParams<T>, Params?> params<T>() =>
      Field<QueryParams<T>, Params?>('params', _$getparams<T>);
}

extension QueryParamsCompareE on QueryParams {
  Map<String, dynamic> compareToQueryParams(QueryParams other) {
    final Map<String, dynamic> diff = {};

    if (filter != other.filter) {
      diff['filter'] = () => other.filter;
    }
    if (params != other.params) {
      diff['params'] = () => other.params;
    }
    return diff;
  }
}
