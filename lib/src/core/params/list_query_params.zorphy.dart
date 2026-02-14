// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'list_query_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, genericArgumentFactories: true)
class ListQueryParams<T> extends Params {
  final String? search;
  @JsonKey(
    includeFromJson: false,
    includeToJson: false,
    toJson: FilterConverter.toJson,
    fromJson: FilterConverter.fromJson,
  )
  final Filter<T>? filter;
  @JsonKey(
    includeFromJson: false,
    includeToJson: false,
    toJson: SortConverter.toJson,
    fromJson: SortConverter.fromJson,
  )
  final Sort<T>? sort;
  final int? limit;
  final int? offset;

  const ListQueryParams({
    Map<String, dynamic>? params,
    this.search,
    this.filter,
    this.sort,
    this.limit,
    this.offset,
  }) : super(params: params);

  ListQueryParams copyWith({
    Map<String, dynamic>? params,
    String? search,
    Filter<T>? filter,
    Sort<T>? sort,
    int? limit,
    int? offset,
  }) {
    return ListQueryParams(
      params: params ?? this.params,
      search: search ?? this.search,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }

  ListQueryParams copyWithListQueryParams({
    Map<String, dynamic>? params,
    String? search,
    Filter<T>? filter,
    Sort<T>? sort,
    int? limit,
    int? offset,
  }) {
    return copyWith(
      params: params,
      search: search,
      filter: filter,
      sort: sort,
      limit: limit,
      offset: offset,
    );
  }

  ListQueryParams copyWithParams({Map<String, dynamic>? params}) {
    return copyWith(params: params);
  }

  ListQueryParams patchWithListQueryParams({ListQueryParamsPatch? patchInput}) {
    final _patcher = patchInput ?? ListQueryParamsPatch();
    final _patchMap = _patcher.toPatch();
    return ListQueryParams(
      params: _patchMap.containsKey(ListQueryParams$.params)
          ? (_patchMap[ListQueryParams$.params] is Function)
                ? _patchMap[ListQueryParams$.params](this.params)
                : _patchMap[ListQueryParams$.params]
          : this.params,
      search: _patchMap.containsKey(ListQueryParams$.search)
          ? (_patchMap[ListQueryParams$.search] is Function)
                ? _patchMap[ListQueryParams$.search](this.search)
                : _patchMap[ListQueryParams$.search]
          : this.search,
      filter: _patchMap.containsKey(ListQueryParams$.filter)
          ? (_patchMap[ListQueryParams$.filter] is Function)
                ? _patchMap[ListQueryParams$.filter](this.filter)
                : _patchMap[ListQueryParams$.filter]
          : this.filter,
      sort: _patchMap.containsKey(ListQueryParams$.sort)
          ? (_patchMap[ListQueryParams$.sort] is Function)
                ? _patchMap[ListQueryParams$.sort](this.sort)
                : _patchMap[ListQueryParams$.sort]
          : this.sort,
      limit: _patchMap.containsKey(ListQueryParams$.limit)
          ? (_patchMap[ListQueryParams$.limit] is Function)
                ? _patchMap[ListQueryParams$.limit](this.limit)
                : _patchMap[ListQueryParams$.limit]
          : this.limit,
      offset: _patchMap.containsKey(ListQueryParams$.offset)
          ? (_patchMap[ListQueryParams$.offset] is Function)
                ? _patchMap[ListQueryParams$.offset](this.offset)
                : _patchMap[ListQueryParams$.offset]
          : this.offset,
    );
  }

  ListQueryParams patchWithParams({ParamsPatch? patchInput}) {
    final _patcher = patchInput ?? ParamsPatch();
    final _patchMap = _patcher.toPatch();
    return ListQueryParams(
      params: _patchMap.containsKey(Params$.params)
          ? (_patchMap[Params$.params] is Function)
                ? _patchMap[Params$.params](this.params)
                : _patchMap[Params$.params]
          : this.params,
      search: this.search,
      filter: this.filter,
      sort: this.sort,
      limit: this.limit,
      offset: this.offset,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ListQueryParams &&
        params == other.params &&
        search == other.search &&
        filter == other.filter &&
        sort == other.sort &&
        limit == other.limit &&
        offset == other.offset;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.params,
      this.search,
      this.filter,
      this.sort,
      this.limit,
      this.offset,
    );
  }

  @override
  String toString() {
    return 'ListQueryParams(' +
        'params: ${params}' +
        ', ' +
        'search: ${search}' +
        ', ' +
        'filter: ${filter}' +
        ', ' +
        'sort: ${sort}' +
        ', ' +
        'limit: ${limit}' +
        ', ' +
        'offset: ${offset})';
  }

  /// Creates a [ListQueryParams] instance from JSON
  factory ListQueryParams.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    final instance = _$ListQueryParamsFromJson(json, fromJsonT);
    return ListQueryParams(
      params: instance.params,
      search: instance.search,
      filter: json['filter'] != null
          ? FilterConverter.fromJson(json['filter'] as Map<String, dynamic>)
                as Filter<T>?
          : null,
      sort: json['sort'] != null
          ? SortConverter.fromJson(json['sort'] as Map<String, dynamic>)
                as Sort<T>?
          : null,
      limit: instance.limit,
      offset: instance.offset,
    );
  }
}

extension ListQueryParamsPropertyHelpers<T> on ListQueryParams<T> {
  bool get hasSearch => search != null;
  bool get noSearch => search == null;
  String get searchRequired =>
      search ?? (throw StateError('search is required but was null'));
  bool get hasFilter => filter != null;
  bool get noFilter => filter == null;
  Filter<T> get filterRequired =>
      filter ?? (throw StateError('filter is required but was null'));
  bool get hasSort => sort != null;
  bool get noSort => sort == null;
  Sort<T> get sortRequired =>
      sort ?? (throw StateError('sort is required but was null'));
  bool get hasLimit => limit != null;
  bool get noLimit => limit == null;
  int get limitRequired =>
      limit ?? (throw StateError('limit is required but was null'));
  bool get hasOffset => offset != null;
  bool get noOffset => offset == null;
  int get offsetRequired =>
      offset ?? (throw StateError('offset is required but was null'));
}

extension ListQueryParamsSerialization<T> on ListQueryParams<T> {
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) {
    final data = _$ListQueryParamsToJson(this, toJsonT);
    if (filter != null) data['filter'] = FilterConverter.toJson(filter!);
    if (sort != null) data['sort'] = SortConverter.toJson(sort!);
    return data;
  }

  Map<String, dynamic> toJsonLean(Object? Function(T value) toJsonT) {
    final Map<String, dynamic> data = _$ListQueryParamsToJson(this, toJsonT);
    if (filter != null) data['filter'] = FilterConverter.toJson(filter!);
    if (sort != null) data['sort'] = SortConverter.toJson(sort!);
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

enum ListQueryParams$ { params, search, filter, sort, limit, offset }

class ListQueryParamsPatch implements Patch<ListQueryParams> {
  final Map<ListQueryParams$, dynamic> _patch = {};

  static ListQueryParamsPatch create([Map<String, dynamic>? diff]) {
    final patch = ListQueryParamsPatch();
    if (diff != null) {
      diff.forEach((key, value) {
        try {
          final enumValue = ListQueryParams$.values.firstWhere(
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

  static ListQueryParamsPatch fromPatch(Map<ListQueryParams$, dynamic> patch) {
    final _patch = ListQueryParamsPatch();
    _patch._patch.addAll(patch);
    return _patch;
  }

  Map<ListQueryParams$, dynamic> toPatch() => Map.from(_patch);

  ListQueryParams applyTo(ListQueryParams entity) {
    return entity.patchWithListQueryParams(patchInput: this);
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

  static ListQueryParamsPatch fromJson(Map<String, dynamic> json) {
    return create(json);
  }

  ListQueryParamsPatch withParams(Map<String, dynamic>? value) {
    _patch[ListQueryParams$.params] = value;
    return this;
  }

  ListQueryParamsPatch withSearch(String? value) {
    _patch[ListQueryParams$.search] = value;
    return this;
  }

  ListQueryParamsPatch withFilter(dynamic value) {
    _patch[ListQueryParams$.filter] = value;
    return this;
  }

  ListQueryParamsPatch withSort(dynamic value) {
    _patch[ListQueryParams$.sort] = value;
    return this;
  }

  ListQueryParamsPatch withLimit(int? value) {
    _patch[ListQueryParams$.limit] = value;
    return this;
  }

  ListQueryParamsPatch withOffset(int? value) {
    _patch[ListQueryParams$.offset] = value;
    return this;
  }
}

/// Field descriptors for [ListQueryParams] query construction
abstract final class ListQueryParamsFields {
  static Map<String, dynamic>? _$getparams<T>(ListQueryParams<T> e) => e.params;
  static Field<ListQueryParams<T>, Map<String, dynamic>?> params<T>() =>
      Field<ListQueryParams<T>, Map<String, dynamic>?>(
        'params',
        _$getparams<T>,
      );
  static String? _$getsearch<T>(ListQueryParams<T> e) => e.search;
  static Field<ListQueryParams<T>, String?> search<T>() =>
      Field<ListQueryParams<T>, String?>('search', _$getsearch<T>);
  static Filter<T>? _$getfilter<T>(ListQueryParams<T> e) => e.filter;
  static Field<ListQueryParams<T>, Filter<T>?> filter<T>() =>
      Field<ListQueryParams<T>, Filter<T>?>('filter', _$getfilter<T>);
  static Sort<T>? _$getsort<T>(ListQueryParams<T> e) => e.sort;
  static Field<ListQueryParams<T>, Sort<T>?> sort<T>() =>
      Field<ListQueryParams<T>, Sort<T>?>('sort', _$getsort<T>);
  static int? _$getlimit<T>(ListQueryParams<T> e) => e.limit;
  static Field<ListQueryParams<T>, int?> limit<T>() =>
      Field<ListQueryParams<T>, int?>('limit', _$getlimit<T>);
  static int? _$getoffset<T>(ListQueryParams<T> e) => e.offset;
  static Field<ListQueryParams<T>, int?> offset<T>() =>
      Field<ListQueryParams<T>, int?>('offset', _$getoffset<T>);
}

extension ListQueryParamsCompareE on ListQueryParams {
  Map<String, dynamic> compareToListQueryParams(ListQueryParams other) {
    final Map<String, dynamic> diff = {};

    if (params != other.params) {
      diff['params'] = () => other.params;
    }
    if (search != other.search) {
      diff['search'] = () => other.search;
    }
    if (filter != other.filter) {
      diff['filter'] = () => other.filter;
    }
    if (sort != other.sort) {
      diff['sort'] = () => other.sort;
    }
    if (limit != other.limit) {
      diff['limit'] = () => other.limit;
    }
    if (offset != other.offset) {
      diff['offset'] = () => other.offset;
    }
    return diff;
  }
}
